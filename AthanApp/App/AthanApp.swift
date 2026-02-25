import SwiftUI
import SwiftData
import UserNotifications
import CoreLocation

// Show notifications even when app is in foreground
class AppDelegate: NSObject, UIApplicationDelegate, CLLocationManagerDelegate {
    let notificationDelegate = NotificationDelegate()

    // MUST be stored property — a local variable would be deallocated
    // before the location event arrives when iOS relaunches a terminated app.
    var backgroundLocationManager: CLLocationManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        BackgroundTaskService.registerBackgroundTasks()
        BackgroundTaskService.scheduleBackgroundRefresh()
        BackgroundTaskService.scheduleProcessingTask()

        // Always start background location monitoring — this ensures monitoring
        // persists across terminations and handles background-location relaunches.
        startBackgroundLocationManager()

        return true
    }

    // MARK: - Background Location Manager

    func startBackgroundLocationManager() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.startMonitoringSignificantLocationChanges()
        backgroundLocationManager = manager
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            // Check if location changed >1km from persisted location
            let shouldRefresh: Bool
            if let saved = SharedDataManager.loadLocation() {
                let savedLocation = CLLocation(latitude: saved.latitude, longitude: saved.longitude)
                shouldRefresh = location.distance(from: savedLocation) > 1000 // 1km
            } else {
                // No saved location — always refresh
                shouldRefresh = true
            }

            if shouldRefresh {
                await BackgroundTaskService.performFullRefresh(
                    newLatitude: location.coordinate.latitude,
                    newLongitude: location.coordinate.longitude
                )
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Background location errors can be ignored — the system will retry
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

@main
struct AthanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var prayerTimesViewModel = PrayerTimesViewModel()
    @State private var locationManager = LocationManager()
    @State private var notificationScheduler = NotificationScheduler()
    @State private var selectedTab = "prayer"

    var sharedModelContainer: ModelContainer = {
        try! ModelContainer(for: UserPreferences.self, CustomAlarm.self)
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView(selectedTab: $selectedTab)
                .id(LanguageManager.shared.currentLanguage)
                .environment(prayerTimesViewModel)
                .environment(locationManager)
                .environment(notificationScheduler)
                .environment(LanguageManager.shared)
                .environment(\.locale, LanguageManager.shared.locale)
                .environment(\.layoutDirection, LanguageManager.shared.isRTL ? .rightToLeft : .leftToRight)
                .task {
                    locationManager.requestWhenInUsePermission()
                    await notificationScheduler.requestPermission()
                    // After getting WhenInUse, request Always for background location updates
                    if locationManager.authorizationStatus == .authorizedWhenInUse {
                        locationManager.requestAlwaysPermission()
                    }
                }
                .onChange(of: locationManager.latitude) { _, _ in
                    onLocationChanged()
                }
                .onChange(of: locationManager.cityName) { _, newCity in
                    guard newCity != "Set Location" else { return }
                    onLocationChanged()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        onBecameActive()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func fetchPreferences() -> UserPreferences? {
        let descriptor = FetchDescriptor<UserPreferences>()
        return try? sharedModelContainer.mainContext.fetch(descriptor).first
    }

    @MainActor
    private func fetchCustomAlarms() -> [CustomAlarm] {
        let descriptor = FetchDescriptor<CustomAlarm>(sortBy: [SortDescriptor(\CustomAlarm.createdAt)])
        return (try? sharedModelContainer.mainContext.fetch(descriptor)) ?? []
    }

    /// Called every time the app comes to foreground — recalculates and reschedules everything.
    private func onBecameActive() {
        prayerTimesViewModel.calculateToday()
        Task { @MainActor in
            await notificationScheduler.rescheduleAll(
                prayerEntries: prayerTimesViewModel.multiDayTimes(),
                preferences: fetchPreferences(),
                customAlarms: fetchCustomAlarms()
            )
        }
    }

    private func onLocationChanged() {
        guard locationManager.latitude != 0 || locationManager.longitude != 0 else { return }
        guard locationManager.cityName != "Set Location" else { return }
        let isManual = locationManager.isManualLocationRequest
        locationManager.isManualLocationRequest = false
        prayerTimesViewModel.updateLocation(
            latitude: locationManager.latitude,
            longitude: locationManager.longitude,
            cityName: locationManager.cityName,
            countryCode: locationManager.countryCode,
            autoSetCalculationMethod: isManual
        )
        Task { @MainActor in
            await notificationScheduler.rescheduleAll(
                prayerEntries: prayerTimesViewModel.multiDayTimes(),
                preferences: fetchPreferences(),
                customAlarms: fetchCustomAlarms()
            )
        }
    }
}
