import CoreLocation

/// Replaces `startMonitoringSignificantLocationChanges()` with a 50km geofence
/// via `CLMonitor`. The app is only woken when the user actually leaves the radius,
/// drastically reducing background location events reported by iOS.
actor GeofenceMonitorService {
    static let shared = GeofenceMonitorService()

    private let geofenceRadius: CLLocationDistance = 50_000 // 50 km
    private let monitorName = "adhanLocationMonitor"
    private let conditionID = "adhanLocationGeofence"
    private var monitor: CLMonitor?
    private var eventTask: Task<Void, any Error>?

    // MARK: - Public API

    /// Call once from `didFinishLaunchingWithOptions`. Creates the monitor and
    /// starts listening for geofence exits. Safe to call repeatedly — subsequent
    /// calls are no-ops while the monitor is already running.
    func startMonitoring() async {
        guard monitor == nil else { return }

        let mon = await CLMonitor(monitorName)
        monitor = mon

        // If we have a saved location, place the initial geofence.
        if let saved = await MainActor.run(body: { SharedDataManager.loadLocation() }) {
            await placeGeofence(latitude: saved.latitude, longitude: saved.longitude, on: mon)
        }

        // Long-running event loop — replays missed events on relaunch.
        eventTask = Task {
            for try await event in await mon.events {
                await self.handleEvent(event, monitor: mon)
            }
        }
    }

    /// Re-center the geofence after a manual city change in the UI.
    func updateGeofenceForManualLocationChange(latitude: Double, longitude: Double) async {
        guard let mon = monitor else { return }
        await placeGeofence(latitude: latitude, longitude: longitude, on: mon)
    }

    // MARK: - Private

    private func placeGeofence(latitude: Double, longitude: Double, on monitor: CLMonitor) async {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let condition = CLMonitor.CircularGeographicCondition(
            center: center,
            radius: geofenceRadius
        )
        await monitor.add(condition, identifier: conditionID, assuming: .satisfied)
    }

    private func handleEvent(_ event: CLMonitor.Event, monitor: CLMonitor) async {
        // We only care about leaving the geofence.
        guard event.state == .unsatisfied else { return }

        // Get a fresh location fix.
        guard let location = await fetchCurrentLocation() else { return }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Refresh prayer times, notifications, and widget.
        await MainActor.run {
            Task {
                await BackgroundTaskService.performFullRefresh(
                    newLatitude: lat,
                    newLongitude: lon
                )
            }
        }

        // Re-center the geofence around the new location.
        await placeGeofence(latitude: lat, longitude: lon, on: monitor)
    }

    /// One-shot location fix with a 15-second timeout.
    private func fetchCurrentLocation() async -> CLLocation? {
        await withThrowingTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates(.default) {
                    if let location = update.location {
                        return location
                    }
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                return nil
            }
            // First result wins — either a location or the timeout.
            let result = try? await group.next(isolation: self) ?? nil
            group.cancelAll()
            return result
        }
    }
}
