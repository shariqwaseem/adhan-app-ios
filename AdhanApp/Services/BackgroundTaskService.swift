import Foundation
import BackgroundTasks
import SwiftData
import CoreLocation
import os.log

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

@MainActor
struct BackgroundTaskService {

    // MARK: - Registration

    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.backgroundRefreshIdentifier,
            using: .main
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleAppRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.processingTaskIdentifier,
            using: .main
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            handleProcessingTask(task: processingTask)
        }
    }

    // MARK: - Scheduling

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Constants.backgroundRefreshIdentifier)
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.day! += 1
        dateComponents.hour = 3
        dateComponents.minute = 0
        request.earliestBeginDate = calendar.date(from: dateComponents)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background task scheduling can fail silently
        }
    }

    static func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: Constants.processingTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600) // 4 hours from now

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Processing task scheduling can fail silently
        }
    }

    // MARK: - Task Handlers

    private static func handleAppRefresh(task: BGAppRefreshTask) {
        AppLogger.background.info("handleAppRefresh: started")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("handleAppRefresh: started")
        Crashlytics.crashlytics().setCustomValue("appRefresh", forKey: "last_bg_task_type")
        Crashlytics.crashlytics().setCustomValue(Date().timeIntervalSince1970, forKey: "last_bg_task_time")
        #endif

        scheduleBackgroundRefresh()

        task.expirationHandler = {
            AppLogger.background.warning("handleAppRefresh: expired by system")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().log("handleAppRefresh: expired by system")
            #endif
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            await performFullRefresh()
            AppLogger.background.info("handleAppRefresh: completed")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().log("handleAppRefresh: completed")
            #endif
            task.setTaskCompleted(success: true)
        }
    }

    private static func handleProcessingTask(task: BGProcessingTask) {
        AppLogger.background.info("handleProcessingTask: started")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("handleProcessingTask: started")
        Crashlytics.crashlytics().setCustomValue("processing", forKey: "last_bg_task_type")
        Crashlytics.crashlytics().setCustomValue(Date().timeIntervalSince1970, forKey: "last_bg_task_time")
        #endif

        scheduleProcessingTask()

        task.expirationHandler = {
            AppLogger.background.warning("handleProcessingTask: expired by system")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().log("handleProcessingTask: expired by system")
            #endif
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            await performFullRefresh()
            AppLogger.background.info("handleProcessingTask: completed")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().log("handleProcessingTask: completed")
            #endif
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Core Engine

    /// The central refresh function. Works from ANY context — background location launch,
    /// BGAppRefreshTask, BGProcessingTask, or foreground.
    /// If new coordinates are provided, reverse geocodes and persists the new location first.
    static func performFullRefresh(
        newLatitude: Double? = nil,
        newLongitude: Double? = nil
    ) async {
        let refreshStart = Date()
        AppLogger.background.info("performFullRefresh: started (newCoords=\(newLatitude != nil))")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("performFullRefresh: started (newCoords=\(newLatitude != nil))")
        #endif

        // Don't reschedule if an alarm was due within the last 10 minutes —
        // cancelAll() inside rescheduleAll would silence a currently-ringing alarm.
        if let fireTime = Constants.sharedDefaults?.object(forKey: Constants.Keys.nextAlarmFireTime) as? Date {
            let elapsed = Date().timeIntervalSince(fireTime)
            if elapsed >= -60 && elapsed < 600 {
                AppLogger.background.info("performFullRefresh: skipped — cooldown active (fireTime=\(fireTime.formatted()))")
                return
            }
        }

        // 1. Determine location
        var latitude: Double
        var longitude: Double
        var cityName: String
        var countryCode: String?

        if let newLat = newLatitude, let newLon = newLongitude {
            // New coordinates provided (e.g. from significant location change)
            latitude = newLat
            longitude = newLon
            cityName = "Unknown"
            countryCode = nil

            // Reverse geocode the new location
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: newLat, longitude: newLon)
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let placemark = placemarks.first {
                cityName = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                countryCode = placemark.isoCountryCode
            }

            // Persist new location
            SharedDataManager.saveLocation(
                latitude: latitude,
                longitude: longitude,
                cityName: cityName,
                countryCode: countryCode
            )
        } else if let saved = SharedDataManager.loadLocation() {
            // Use persisted location
            latitude = saved.latitude
            longitude = saved.longitude
            cityName = saved.cityName
            countryCode = saved.countryCode
        } else {
            // No location available — nothing to do
            return
        }

        // 2. Load preferences and custom alarms from SwiftData
        let container: ModelContainer? = try? ModelContainer(for: UserPreferences.self, CustomAlarm.self)

        let prefs: UserPreferences? = {
            guard let container else { return nil }
            let descriptor = FetchDescriptor<UserPreferences>()
            return try? container.mainContext.fetch(descriptor).first
        }()

        let customAlarms: [CustomAlarm] = {
            guard let container else { return [] }
            let descriptor = FetchDescriptor<CustomAlarm>(sortBy: [SortDescriptor(\CustomAlarm.createdAt)])
            return (try? container.mainContext.fetch(descriptor)) ?? []
        }()

        // 3. Resolve the same versioned Auto/preset/Custom payload used by the app and widget.
        let calculationSettings = CalculationSettingsStorage.preferred([
            CalculationSettingsStorage.decode(prefs?.calculationSettingsData),
            SharedDataManager.loadCalculationSettings(),
        ]) ?? CalculationSettingsPayload()
        let calculationConfiguration = calculationSettings.selection.resolved(countryCode: countryCode)

        let asrMethod: AsrJuristicMethod = {
            if let prefs, let method = AsrJuristicMethod(rawValue: prefs.asrJuristicMethodRawValue) {
                return method
            }
            if let method = SharedDataManager.loadAsrMethod() {
                return method
            }
            return .hanafi
        }()

        let highLatitudeRule: HighLatitudeRuleOption = {
            if let prefs, let rule = HighLatitudeRuleOption(rawValue: prefs.highLatitudeRuleRawValue) {
                return rule
            }
            if let rule = SharedDataManager.loadHighLatitudeRule() {
                return rule
            }
            return .middleOfTheNight
        }()

        // 4. Calculate prayer times for N days
        AppLogger.background.info("performFullRefresh: calculating for (\(latitude), \(longitude)) method=\(calculationConfiguration.logName) hlr=\(highLatitudeRule.rawValue)")
        let service = PrayerCalculationService()
        let days = Constants.NotificationBudget.daysToScheduleAhead
        let multiDayEntries = service.calculateMultipleDays(
            startDate: Date(),
            days: days,
            latitude: latitude,
            longitude: longitude,
            configuration: calculationConfiguration,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule,
            adjustments: SharedDataManager.loadManualAdjustments()
        )

        // Log today's Isha specifically (the prayer we're debugging)
        if let todayEntries = multiDayEntries.first,
           let isha = todayEntries.first(where: { $0.prayer == .isha }) {
            AppLogger.background.info("performFullRefresh: today's Isha = \(isha.adjustedTime.formatted(date: .abbreviated, time: .standard))")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().log("bg_isha_time: \(isha.adjustedTime.formatted(date: .abbreviated, time: .standard))")
            #endif
            #if canImport(FirebaseAnalytics)
            Analytics.logEvent("background_refresh", parameters: [
                "latitude": latitude,
                "longitude": longitude,
                "method": calculationConfiguration.logName,
                "isha_hour": Calendar.current.component(.hour, from: isha.adjustedTime),
                "isha_minute": Calendar.current.component(.minute, from: isha.adjustedTime)
            ])
            #endif
        }

        // 5. Reschedule all notifications/alarms
        let scheduler = NotificationScheduler()
        await scheduler.rescheduleAll(
            prayerEntries: multiDayEntries,
            preferences: prefs,
            customAlarms: customAlarms
        )
        let refreshDuration = Date().timeIntervalSince(refreshStart)
        AppLogger.background.info("performFullRefresh: scheduling completed in \(String(format: "%.2f", refreshDuration))s")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("performFullRefresh: scheduling completed in \(String(format: "%.2f", refreshDuration))s")
        Crashlytics.crashlytics().setCustomValue(refreshDuration, forKey: "last_refresh_duration_sec")
        #endif

        // 6. Update widget data with today's times
        if let todayEntries = multiDayEntries.first {
            let hijriDate = HijriDateService().hijriDateString(for: Date())
            let daily = DailyPrayerTimes(
                date: Date(),
                entries: todayEntries,
                cityName: cityName,
                hijriDate: hijriDate
            )
            SharedDataManager.savePrayerTimes(daily)
            SharedDataManager.reloadWidgets()
        }

        // 7. Record refresh timestamp
        Constants.sharedDefaults?.set(Date(), forKey: Constants.Keys.lastBackgroundRefreshDate)
    }
}
