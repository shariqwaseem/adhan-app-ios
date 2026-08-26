import SwiftUI
import SwiftData
import UserNotifications
import ActivityKit
import Intents

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
        let isTakingScreenshots = UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT")

        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif

        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationDelegate.registerCategories()
        if !isTakingScreenshots {
            BackgroundTaskService.registerBackgroundTasks()
            BackgroundTaskService.scheduleBackgroundRefresh()
            BackgroundTaskService.scheduleProcessingTask()
        }

        // Significant-change monitoring is started after onboarding completes
        // (see AdhanApp.onBecameActive) to avoid prompting for location
        // permission before the user reaches the onboarding location step.
        let wasLaunchedForLocation = launchOptions?[.location] != nil
        if !isTakingScreenshots &&
            (wasLaunchedForLocation || UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")) {
            Task { @MainActor in
                SignificantLocationChangeService.shared.startMonitoringIfAuthorized()
            }
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
    @State private var reviewPromptManager = ReviewPromptManager()
    @State private var selectedTab = "prayer"
    @State private var isActivating = false
    @State private var locationChangedDuringActivation = false
    @State private var lastForegroundSchedule: Date?
    @State private var hasHandledInitialReviewActivation = false
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
                .environment(reviewPromptManager)
                .environment(LanguageManager.shared)
                .environment(\.locale, LanguageManager.shared.locale)
                .environment(\.layoutDirection, LanguageManager.shared.isRTL ? .rightToLeft : .leftToRight)
                .task {
                    configureForScreenshotsIfNeeded()
                    let shouldHandleInitialActivation = !hasHandledInitialReviewActivation
                    hasHandledInitialReviewActivation = true
                    if shouldHandleInitialActivation, scenePhase == .active {
                        recordReviewPromptSession()
                    }
                }
                .onChange(of: locationManager.latitude) { _, _ in
                    onLocationChanged()
                }
                .onChange(of: locationManager.cityName) { _, newCity in
                    guard newCity != "Set Location" else { return }
                    onLocationChanged()
                }
                .onChange(of: hasCompletedOnboarding) { _, completed in
                    if completed {
                        onOnboardingCompleted()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        onBecameActive()
                        recordReviewPromptSession()
                    } else {
                        reviewPromptManager.appBecameInactive()
                    }
                }
                .onChange(of: LanguageManager.shared.currentLanguage) { _, _ in
                    guard hasCompletedOnboarding else { return }
                    Task { @MainActor in
                        await notificationScheduler.rescheduleAll(
                            prayerEntries: prayerTimesViewModel.multiDayTimes(),
                            preferences: fetchPreferences(),
                            customAlarms: fetchCustomAlarms(),
                            reason: .languageChange
                        )
                    }
                }
                .onOpenURL { url in
                    guard url.scheme == "adhanpro" else { return }

                    switch url.host {
                    case "cancel-alarm":
                        #if canImport(AlarmKit)
                        if #available(iOS 26, *) {
                            let mgr = AlarmKit.AlarmManager.shared
                            if let alarms = try? mgr.alarms {
                                for alarm in alarms {
                                    try? mgr.cancel(id: alarm.id)
                                }
                            }
                            Task {
                                await AlarmLiveActivityCleanup.endAllActivities()
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
                .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
                    guard let data = NSUbiquitousKeyValueStore.default.data(forKey: CalculationSettingsStorage.iCloudKey),
                          let incoming = CalculationSettingsStorage.decode(data),
                          prayerTimesViewModel.mergeCalculationSettings(incoming) else { return }
                    syncCalculationPreferencesIfPresent()
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
    private func configureForScreenshotsIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "FASTLANE_SCREENSHOTS") else { return }

        locationManager.authorizationStatus = .authorizedWhenInUse
        locationManager.isAuthorized = true
        locationManager.latitude = 35.277611
        locationManager.longitude = 75.639778
        locationManager.cityName = screenshotCityName
        locationManager.countryCode = "PK"
        notificationScheduler.isPermissionGranted = true
        notificationScheduler.alarmManager.isAuthorized = true

        prayerTimesViewModel.latitude = 35.277611
        prayerTimesViewModel.longitude = 75.639778
        prayerTimesViewModel.cityName = screenshotCityName
        prayerTimesViewModel.countryCode = "PK"
        prayerTimesViewModel.calculateToday()

        let preferences = fetchPreferences() ?? {
            let newPreferences = UserPreferences()
            sharedModelContainer.mainContext.insert(newPreferences)
            return newPreferences
        }()
        preferences.fajrNotificationMode = PrayerNotificationMode.alarm.rawValue
        preferences.fajrAlarmAudio = ""
        try? sharedModelContainer.mainContext.save()
    }

    private var screenshotCityName: String {
        "Skardu"
    }

    @MainActor
    private func fetchCustomAlarms() -> [CustomAlarm] {
        let descriptor = FetchDescriptor<CustomAlarm>(sortBy: [SortDescriptor(\CustomAlarm.createdAt)])
        return (try? sharedModelContainer.mainContext.fetch(descriptor)) ?? []
    }

    /// Called every time the app comes to foreground — recalculates and reschedules everything.
    private func onBecameActive() {
        guard !UserDefaults.standard.bool(forKey: "FASTLANE_SCREENSHOTS") else { return }

        // Clean up orphaned AlarmKit Live Activities without stopping active/snoozing alarms.
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            Task {
                await AlarmLiveActivityCleanup.endActivitiesWithoutCurrentAlarm()
            }
        }
        #endif

        guard hasCompletedOnboarding else { return }
        requestSiriAuthorizationIfNeeded()
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

                // Location changed while scheduling — redo with fresh coordinates
                if locationChangedDuringActivation {
                    locationChangedDuringActivation = false
                    await notificationScheduler.rescheduleAll(
                        prayerEntries: prayerTimesViewModel.multiDayTimes(),
                        preferences: fetchPreferences(),
                        customAlarms: fetchCustomAlarms()
                    )
                    lastForegroundSchedule = Date()
                }

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

        // Start significant-change monitoring once onboarding is done (handles the case
        // where the app launched during onboarding and skipped it in AppDelegate).
        if hasCompletedOnboarding {
            Task { @MainActor in
                SignificantLocationChangeService.shared.startMonitoringIfAuthorized()
            }
        }
    }

    private func onLocationChanged() {
        guard !UserDefaults.standard.bool(forKey: "FASTLANE_SCREENSHOTS") else { return }
        guard locationManager.latitude != 0 || locationManager.longitude != 0 else { return }
        guard locationManager.cityName != "Set Location" else { return }
        let shouldSchedule = hasCompletedOnboarding
        prayerTimesViewModel.updateLocation(
            latitude: locationManager.latitude,
            longitude: locationManager.longitude,
            cityName: locationManager.cityName,
            countryCode: locationManager.countryCode
        )
        syncCalculationPreferencesIfPresent()
        guard shouldSchedule else { return }

        // Defer rescheduling if onBecameActive() is in progress — it will
        // redo with fresh data once it finishes.
        if isActivating {
            locationChangedDuringActivation = true
            return
        }
        Task { @MainActor in
            await notificationScheduler.rescheduleAll(
                prayerEntries: prayerTimesViewModel.multiDayTimes(),
                preferences: fetchPreferences(),
                customAlarms: fetchCustomAlarms()
            )
        }
    }

    private func onOnboardingCompleted() {
        guard !UserDefaults.standard.bool(forKey: "FASTLANE_SCREENSHOTS") else { return }

        if scenePhase == .active {
            recordReviewPromptSession()
        }
        onLocationChanged()
        requestSiriAuthorizationIfNeeded()

        if locationManager.isAuthorized,
           (locationManager.cityName == "Set Location" ||
            (locationManager.latitude == 0 && locationManager.longitude == 0)) {
            locationManager.requestLocation()
        }

        Task { @MainActor in
            SignificantLocationChangeService.shared.startMonitoringIfAuthorized()
        }
    }

    private func recordReviewPromptSession() {
        let defaults = UserDefaults.standard
        reviewPromptManager.appBecameActive(
            hasCompletedOnboarding: hasCompletedOnboarding,
            isTakingScreenshots: defaults.bool(forKey: "FASTLANE_SCREENSHOTS")
                || defaults.bool(forKey: "FASTLANE_SNAPSHOT")
        )
    }

    private func requestSiriAuthorizationIfNeeded() {
        guard INPreferences.siriAuthorizationStatus() == .notDetermined else { return }
        INPreferences.requestSiriAuthorization { status in
            AppLogger.lifecycle.info("Siri authorization status: \(String(describing: status))")
        }
    }

    @MainActor
    private func syncCalculationPreferencesIfPresent() {
        guard let prefs = fetchPreferences() else { return }
        prefs.calculationSettingsData = prayerTimesViewModel.calculationSettingsData
        prefs.calculationMethodRawValue = prayerTimesViewModel.resolvedCalculationConfiguration.logName
        prefs.asrJuristicMethodRawValue = prayerTimesViewModel.asrMethod.rawValue
        prefs.highLatitudeRuleRawValue = prayerTimesViewModel.highLatitudeRule.rawValue
        try? sharedModelContainer.mainContext.save()
    }
}
