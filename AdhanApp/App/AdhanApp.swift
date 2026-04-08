import SwiftUI
import SwiftData
import UserNotifications
import ActivityKit

#if canImport(AlarmKit)
import AlarmKit
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

// Show notifications even when app is in foreground
class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationDelegate = NotificationDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif

        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationDelegate.registerCategories()
        BackgroundTaskService.registerBackgroundTasks()
        BackgroundTaskService.scheduleBackgroundRefresh()
        BackgroundTaskService.scheduleProcessingTask()

        // Geofence monitoring is started after onboarding completes
        // (see AdhanApp.onBecameActive) to avoid prompting for location
        // permission before the user reaches the onboarding location step.
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            Task { await GeofenceMonitorService.shared.startMonitoring() }
        }

        AppLogger.lifecycle.info("didFinishLaunchingWithOptions: completed")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("didFinishLaunchingWithOptions: completed")
        Crashlytics.crashlytics().setCustomValue("launched", forKey: "app_state")
        #endif

        return true
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Register notification categories for all alarm types.
    static func registerCategories() {
        let categoryIDs = ["PRAYER_TIME", "PRAYER_PRE_ALARM", "CUSTOM_ALARM", "CUSTOM_PRE_ALARM"]
        let categories: Set<UNNotificationCategory> = Set(categoryIDs.map { id in
            UNNotificationCategory(
                identifier: id,
                actions: [],
                intentIdentifiers: []
            )
        })
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
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
    @State private var isActivating = false
    @State private var lastForegroundSchedule: Date?
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
                .onOpenURL { url in
                    guard url.scheme == "adhanpro" else { return }

                    switch url.host {
                    case "cancel-alarm":
                        // Cancel all active AlarmKit alarms (stops the snooze countdown)
                        #if canImport(AlarmKit)
                        if #available(iOS 26, *) {
                            let mgr = AlarmKit.AlarmManager.shared
                            if let alarms = try? mgr.alarms {
                                for alarm in alarms {
                                    try? mgr.cancel(id: alarm.id)
                                }
                            }
                        }
                        #endif

                    default:
                        break
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                    prayerTimesViewModel.recalculate()
                    Task { @MainActor in
                        await notificationScheduler.rescheduleAll(
                            prayerEntries: prayerTimesViewModel.multiDayTimes(),
                            preferences: fetchPreferences(),
                            customAlarms: fetchCustomAlarms()
                        )
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
        // Clean up any stale AlarmKit Live Activities (alarm + snooze window expired while app was in background)
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            Task {
                for activity in Activity<AlarmAttributes<AdhanAlarmMetadata>>.activities {
                    if let prayerTime = activity.attributes.metadata?.prayerTime,
                       prayerTime.addingTimeInterval(5 * 60) <= Date() {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
        }
        #endif

        guard hasCompletedOnboarding else { return }
        isActivating = true
        AppLogger.lifecycle.info("onBecameActive: started")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("onBecameActive: started")
        Crashlytics.crashlytics().setCustomValue("active", forKey: "app_state")
        #endif

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

        // Only reschedule on foreground if last schedule was > 5 min ago
        let shouldSchedule: Bool
        if let last = lastForegroundSchedule {
            shouldSchedule = Date().timeIntervalSince(last) > 300
        } else {
            shouldSchedule = true
        }

        if shouldSchedule {
            Task { @MainActor in
                await notificationScheduler.rescheduleAll(
                    prayerEntries: prayerTimesViewModel.multiDayTimes(),
                    preferences: fetchPreferences(),
                    customAlarms: fetchCustomAlarms()
                )
                lastForegroundSchedule = Date()
                isActivating = false
                AppLogger.lifecycle.info("onBecameActive: completed (rescheduled)")
                #if canImport(FirebaseCrashlytics)
                Crashlytics.crashlytics().log("onBecameActive: completed (rescheduled)")
                #endif
            }
        } else {
            isActivating = false
            AppLogger.lifecycle.info("onBecameActive: completed (skipped reschedule)")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().log("onBecameActive: completed (skipped reschedule)")
            #endif
        }

        // Request a fresh location only if stale (>30 min) — avoids unnecessary
        // location fetches when rapidly switching in/out of the app.
        if locationManager.isAuthorized,
           locationManager.lastLocationUpdate == nil ||
           locationManager.lastLocationUpdate!.timeIntervalSinceNow < -1800 {
            locationManager.requestLocation()
        }

        // Start geofence monitoring once onboarding is done (handles the case
        // where the app launched during onboarding and skipped it in AppDelegate).
        if hasCompletedOnboarding {
            Task { await GeofenceMonitorService.shared.startMonitoring() }
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
        // Skip rescheduling if onBecameActive() is already handling it
        guard !isActivating else { return }
        Task { @MainActor in
            await notificationScheduler.rescheduleAll(
                prayerEntries: prayerTimesViewModel.multiDayTimes(),
                preferences: fetchPreferences(),
                customAlarms: fetchCustomAlarms()
            )
        }
    }
}
