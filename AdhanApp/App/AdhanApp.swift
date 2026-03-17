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
        NotificationDelegate.registerCategories()
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
        manager.pausesLocationUpdatesAutomatically = true
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
                shouldRefresh = location.distance(from: savedLocation) > 25_000 // 25km – city-level change
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

    static let snoozeActionIdentifier = "SNOOZE_ACTION"

    /// Register notification categories with a snooze action for all alarm types.
    static func registerCategories() {
        let snoozeAction = UNNotificationAction(
            identifier: snoozeActionIdentifier,
            title: String(localized: "Snooze (5 min)", bundle: LanguageManager.shared.bundle),
            options: []
        )
        let categoryIDs = ["PRAYER_TIME", "PRAYER_PRE_ALARM", "CUSTOM_ALARM", "CUSTOM_PRE_ALARM"]
        let categories: Set<UNNotificationCategory> = Set(categoryIDs.map { id in
            UNNotificationCategory(
                identifier: id,
                actions: [snoozeAction],
                intentIdentifiers: []
            )
        })
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == Self.snoozeActionIdentifier else { return }

        let original = response.notification.request.content
        let content = UNMutableNotificationContent()
        content.title = original.title
        content.body = original.body
        content.categoryIdentifier = original.categoryIdentifier
        content.sound = original.sound ?? .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        let identifier = "snooze_\(response.notification.request.identifier)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await center.add(request)
    }
}

@main
struct AdhanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var prayerTimesViewModel = PrayerTimesViewModel()
    @State private var locationManager = LocationManager()
    @State private var notificationScheduler = NotificationScheduler()
    @State private var downloadManager = AdhanAudioDownloadManager()
    @State private var selectedTab = "prayer"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var sharedModelContainer: ModelContainer = {
        try! ModelContainer(for: UserPreferences.self, CustomAlarm.self)
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainTabView(selectedTab: $selectedTab)
                } else {
                    OnboardingView()
                }
            }
                .id(LanguageManager.shared.currentLanguage)
                .environment(prayerTimesViewModel)
                .environment(locationManager)
                .environment(notificationScheduler)
                .environment(downloadManager)
                .environment(LanguageManager.shared)
                .environment(\.locale, LanguageManager.shared.locale)
                .environment(\.layoutDirection, LanguageManager.shared.isRTL ? .rightToLeft : .leftToRight)
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
        // If the background location manager persisted a new location while we were
        // suspended, sync it into the view model so prayer times are immediately correct.
        if let saved = SharedDataManager.loadLocation(),
           (saved.latitude != prayerTimesViewModel.latitude ||
            saved.longitude != prayerTimesViewModel.longitude) {
            prayerTimesViewModel.updateLocation(
                latitude: saved.latitude,
                longitude: saved.longitude,
                cityName: saved.cityName,
                countryCode: saved.countryCode
            )
        } else {
            prayerTimesViewModel.calculateToday()
        }

        // Verify downloaded sounds — reset preferences for any missing files
        let missingIDs = Set(downloadManager.verifyDownloadedSounds())
        if !missingIDs.isEmpty, let prefs = fetchPreferences() {
            let audioFields: [ReferenceWritableKeyPath<UserPreferences, String>] = [
                \.tahajjudAlarmAudio, \.fajrAlarmAudio, \.dhuhrAlarmAudio,
                \.asrAlarmAudio, \.maghribAlarmAudio, \.ishaAlarmAudio
            ]
            for keyPath in audioFields {
                if missingIDs.contains(prefs[keyPath: keyPath]) {
                    prefs[keyPath: keyPath] = ""
                }
            }
            for alarm in fetchCustomAlarms() where missingIDs.contains(alarm.alarmAudio) {
                alarm.alarmAudio = ""
            }
        }

        Task { @MainActor in
            await notificationScheduler.rescheduleAll(
                prayerEntries: prayerTimesViewModel.multiDayTimes(),
                preferences: fetchPreferences(),
                customAlarms: fetchCustomAlarms()
            )
        }

        // Request a fresh location only if stale (>30 min) — avoids unnecessary
        // location fetches when rapidly switching in/out of the app.
        if locationManager.isAuthorized,
           locationManager.lastLocationUpdate == nil ||
           locationManager.lastLocationUpdate!.timeIntervalSinceNow < -1800 {
            locationManager.requestLocation()
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
