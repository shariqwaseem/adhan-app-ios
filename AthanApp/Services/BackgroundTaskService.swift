import Foundation
import BackgroundTasks
import SwiftData
import CoreLocation

@MainActor
struct BackgroundTaskService {

    // MARK: - Registration

    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.backgroundRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleAppRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.processingTaskIdentifier,
            using: nil
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
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            await performFullRefresh()
            task.setTaskCompleted(success: true)
        }
    }

    private static func handleProcessingTask(task: BGProcessingTask) {
        scheduleProcessingTask()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            await performFullRefresh()
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

        // 2. Load preferences from SwiftData
        let prefs: UserPreferences? = {
            guard let container = try? ModelContainer(for: UserPreferences.self) else { return nil }
            let descriptor = FetchDescriptor<UserPreferences>()
            return try? container.mainContext.fetch(descriptor).first
        }()

        // 3. Determine calculation parameters from preferences or country code
        let calculationMethod: CalculationMethodInfo = {
            if let prefs,
               let method = CalculationMethodInfo(rawValue: prefs.calculationMethodRawValue) {
                return method
            }
            if let code = countryCode {
                return CalculationMethodInfo.recommendedMethod(forCountryCode: code)
            }
            return .MuslimWorldLeague
        }()

        let asrMethod: AsrJuristicMethod = {
            if let prefs, let method = AsrJuristicMethod(rawValue: prefs.asrJuristicMethodRawValue) {
                return method
            }
            return .standard
        }()

        let highLatitudeRule: HighLatitudeRuleOption = {
            if let prefs, let rule = HighLatitudeRuleOption(rawValue: prefs.highLatitudeRuleRawValue) {
                return rule
            }
            return .middleOfTheNight
        }()

        // 4. Calculate prayer times for N days
        let service = PrayerCalculationService()
        let days = Constants.NotificationBudget.daysToScheduleAhead
        let multiDayEntries = service.calculateMultipleDays(
            startDate: Date(),
            days: days,
            latitude: latitude,
            longitude: longitude,
            method: calculationMethod,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule,
            adjustments: [:]
        )

        // 5. Reschedule all notifications/alarms
        let scheduler = NotificationScheduler()
        await scheduler.rescheduleAll(
            prayerEntries: multiDayEntries,
            preferences: prefs
        )

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
