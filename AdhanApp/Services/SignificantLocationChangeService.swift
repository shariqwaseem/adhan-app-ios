import CoreLocation

/// Uses Core Location's significant-change service for coarse travel updates.
/// This does not require `UIBackgroundModes.location`; iOS relaunches the app
/// for significant location events after the user grants Always authorization.
@MainActor
final class SignificantLocationChangeService: NSObject {
    static let shared = SignificantLocationChangeService()

    private let manager = CLLocationManager()
    private let minimumRefreshDistance: CLLocationDistance = 20_000
    private var isMonitoring = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.pausesLocationUpdatesAutomatically = true
    }

    // MARK: - Public API

    /// Safe to call on launch, after onboarding, and when returning foreground.
    func startMonitoringIfAuthorized() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        guard manager.authorizationStatus == .authorizedAlways else {
            stopMonitoring()
            return
        }
        guard !isMonitoring else { return }

        manager.startMonitoringSignificantLocationChanges()
        isMonitoring = true
        AppLogger.background.info("Significant location monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        manager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
        AppLogger.background.info("Significant location monitoring stopped")
    }

    // MARK: - Private

    private func handleSignificantLocation(_ location: CLLocation) {
        let age = abs(location.timestamp.timeIntervalSinceNow)
        guard age < 30 * 60 else {
            AppLogger.background.info("Significant location ignored because it is stale")
            return
        }

        if let saved = SharedDataManager.loadLocation() {
            let previous = CLLocation(latitude: saved.latitude, longitude: saved.longitude)
            let distance = previous.distance(from: location)
            guard distance >= minimumRefreshDistance else {
                AppLogger.background.info("Significant location ignored because movement was below refresh threshold")
                return
            }
        }

        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        AppLogger.background.info("Significant location accepted; refreshing prayer schedule")

        Task { @MainActor in
            await BackgroundTaskService.performFullRefresh(
                newLatitude: latitude,
                newLongitude: longitude
            )
        }
    }
}

extension SignificantLocationChangeService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            self.handleSignificantLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.background.error("Significant location failed: \(error.localizedDescription)")
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
