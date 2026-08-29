import CoreLocation

/// Monitors a single 25 km on-device travel boundary.
///
/// `CLMonitor` is intentionally used instead of significant-change updates so
/// Core Location applies the distance threshold before waking the app. This
/// does not use the continuous `location` background mode.
@MainActor
final class SignificantLocationChangeService: NSObject {
    static let shared = SignificantLocationChangeService()

    private static let travelRadius: CLLocationDistance = 25_000
    private static let maximumCachedLocationAge: TimeInterval = 5 * 60
    private static let maximumLocationAccuracy: CLLocationAccuracy = 5_000

    private let manager = CLLocationManager()
    private let monitorName = "adhanLocationMonitor"
    private let conditionIdentifier = "adhanLocationGeofence"

    private var monitor: CLMonitor?
    private var monitorSetupTask: Task<Void, Never>?
    private var pendingCenter: CLLocationCoordinate2D?
    private var eventTask: Task<Void, Never>?
    private var serviceSession: CLServiceSession?
    private var isResolvingExit = false
    private var locationRequestAttempts = 0

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public API

    /// Safe to call on launch, after onboarding, and when the saved location changes.
    func startMonitoringIfAuthorized() {
        // Migration from builds that used significant-change monitoring. This
        // must be unconditional because that registration survives app exits.
        manager.stopMonitoringSignificantLocationChanges()

        guard CLLocationManager.locationServicesEnabled(),
              manager.authorizationStatus == .authorizedAlways else {
            stopMonitoring()
            return
        }

        if serviceSession == nil {
            serviceSession = CLServiceSession(authorization: .always)
        }

        guard let saved = SharedDataManager.loadLocation() else { return }
        let center = CLLocationCoordinate2D(
            latitude: saved.latitude,
            longitude: saved.longitude
        )

        pendingCenter = center
        guard monitorSetupTask == nil else { return }
        monitorSetupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while let center = self.pendingCenter, !Task.isCancelled {
                self.pendingCenter = nil
                await self.configureMonitor(centeredAt: center)
            }
            self.monitorSetupTask = nil
        }
    }

    func stopMonitoring() {
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopUpdatingLocation()
        isResolvingExit = false
        locationRequestAttempts = 0

        monitorSetupTask?.cancel()
        monitorSetupTask = nil
        pendingCenter = nil
        eventTask?.cancel()
        eventTask = nil

        serviceSession?.invalidate()
        serviceSession = nil

        if let monitor {
            Task {
                await monitor.remove(conditionIdentifier)
            }
        }
        monitor = nil
        AppLogger.background.info("Travel boundary monitoring stopped")
    }

    // MARK: - Monitor lifecycle

    private func configureMonitor(centeredAt center: CLLocationCoordinate2D) async {
        guard manager.authorizationStatus == .authorizedAlways else { return }

        let monitor: CLMonitor
        if let existing = self.monitor {
            monitor = existing
        } else {
            monitor = await CLMonitor(monitorName)
            guard !Task.isCancelled,
                  manager.authorizationStatus == .authorizedAlways else { return }
            self.monitor = monitor
            listenForEvents(from: monitor)
        }

        if let record = await monitor.record(for: conditionIdentifier),
           let condition = record.condition as? CLMonitor.CircularGeographicCondition,
           abs(condition.radius - Self.travelRadius) < 1,
           locationsAreEquivalent(condition.center, center) {
            AppLogger.background.info("25 km travel boundary monitoring active")
            return
        }

        await replaceCondition(on: monitor, centeredAt: center)
        AppLogger.background.info("25 km travel boundary monitoring started")
    }

    private func listenForEvents(from monitor: CLMonitor) {
        guard eventTask == nil else { return }

        eventTask = Task { @MainActor [weak self] in
            do {
                for try await event in await monitor.events {
                    guard !Task.isCancelled else { return }
                    self?.handleMonitorEvent(event)
                }
            } catch is CancellationError {
                return
            } catch {
                AppLogger.background.error("Travel boundary monitoring failed: \(error.localizedDescription)")
            }
        }
    }

    private func replaceCondition(
        on monitor: CLMonitor,
        centeredAt center: CLLocationCoordinate2D
    ) async {
        if await monitor.record(for: conditionIdentifier) != nil {
            await monitor.remove(conditionIdentifier)
        }

        let condition = CLMonitor.CircularGeographicCondition(
            center: center,
            radius: Self.travelRadius
        )
        await monitor.add(
            condition,
            identifier: conditionIdentifier,
            assuming: .satisfied
        )
    }

    private func locationsAreEquivalent(
        _ first: CLLocationCoordinate2D,
        _ second: CLLocationCoordinate2D
    ) -> Bool {
        let firstLocation = CLLocation(latitude: first.latitude, longitude: first.longitude)
        let secondLocation = CLLocation(latitude: second.latitude, longitude: second.longitude)
        return firstLocation.distance(from: secondLocation) < 1
    }

    // MARK: - Exit handling

    private func handleMonitorEvent(_ event: CLMonitor.Event) {
        guard event.identifier == conditionIdentifier,
              event.state == .unsatisfied,
              !isResolvingExit else { return }

        isResolvingExit = true
        locationRequestAttempts = 0
        AppLogger.background.info("25 km travel boundary exited")

        if let cached = manager.location, isUsable(cached) {
            handleBoundaryLocation(cached)
        } else {
            requestCurrentLocation()
        }
    }

    private func requestCurrentLocation() {
        locationRequestAttempts += 1
        manager.requestLocation()
    }

    private func isUsable(_ location: CLLocation) -> Bool {
        let age = abs(location.timestamp.timeIntervalSinceNow)
        return age <= Self.maximumCachedLocationAge
            && location.horizontalAccuracy >= 0
            && location.horizontalAccuracy <= Self.maximumLocationAccuracy
    }

    private func handleBoundaryLocation(_ location: CLLocation) {
        guard isResolvingExit else { return }

        guard isUsable(location) else {
            if locationRequestAttempts < 2 {
                requestCurrentLocation()
            } else {
                finishFailedExitResolution(reason: "no recent location was available")
            }
            return
        }

        if let saved = SharedDataManager.loadLocation() {
            let anchor = CLLocation(latitude: saved.latitude, longitude: saved.longitude)
            let distance = anchor.distance(from: location)
            guard distance >= Self.travelRadius else {
                finishFailedExitResolution(reason: "the verified distance was below 25 km")
                return
            }
        }

        isResolvingExit = false
        locationRequestAttempts = 0
        let coordinate = location.coordinate
        AppLogger.background.info("25 km travel boundary accepted; refreshing prayer schedule")

        Task { @MainActor [weak self] in
            await BackgroundTaskService.performFullRefresh(
                newLatitude: coordinate.latitude,
                newLongitude: coordinate.longitude
            )
            guard let self, let monitor = self.monitor else { return }
            await self.replaceCondition(on: monitor, centeredAt: coordinate)
        }
    }

    private func finishFailedExitResolution(reason: String) {
        isResolvingExit = false
        locationRequestAttempts = 0
        AppLogger.background.info("Travel boundary exit ignored because \(reason)")

        // Restore the original 25 km condition so a noisy boundary event does
        // not permanently prevent a later, genuine exit from being delivered.
        guard let saved = SharedDataManager.loadLocation(), let monitor else { return }
        let center = CLLocationCoordinate2D(latitude: saved.latitude, longitude: saved.longitude)
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.replaceCondition(on: monitor, centeredAt: center)
        }
    }
}

extension SignificantLocationChangeService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            self.handleBoundaryLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            guard self.isResolvingExit else { return }
            if self.locationRequestAttempts < 2 {
                self.requestCurrentLocation()
            } else {
                self.finishFailedExitResolution(reason: error.localizedDescription)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            if status == .authorizedAlways {
                self.startMonitoringIfAuthorized()
            } else {
                self.stopMonitoring()
            }
        }
    }
}
