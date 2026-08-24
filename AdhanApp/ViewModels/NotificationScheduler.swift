import Foundation
import UserNotifications
import Observation
import os.log
import ActivityKit

#if canImport(AlarmKit)
import AlarmKit
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

@Observable
@MainActor
final class NotificationScheduler {
    enum RescheduleReason: Equatable {
        case routine
        case languageChange
    }

    var isPermissionGranted: Bool = false
    private static var schedulingTask: (id: UUID, task: Task<Void, Never>)?
    var nextScheduledAlarmTime: Date? = nil
    var nextScheduledIsAlarm: Bool = false
    var nextScheduledName: String? = nil
    private var scheduledAlarmTimes: [String: [Date]] = [:]  // tracking AlarmKit-scheduled fire dates

    var alarmManager = AdhanAlarmManager()

    func checkNotificationPermission() async {
        if UserDefaults.standard.bool(forKey: "FASTLANE_SCREENSHOTS") {
            isPermissionGranted = true
            return
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isPermissionGranted = settings.authorizationStatus == .authorized
    }

    func requestPermission() async {
        do {
            isPermissionGranted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            isPermissionGranted = false
        }
    }

    private static let alarmCooldown: TimeInterval = 600 // 10 minutes

    func rescheduleAll(
        prayerEntries: [[PrayerTimeEntry]],
        preferences: UserPreferences?,
        customAlarms: [CustomAlarm] = [],
        reason: RescheduleReason = .routine
    ) async {
        // Location, time-zone, and foreground events can each create their own scheduler.
        // Queue every pass process-wide so cancel-and-rebuild operations cannot interleave.
        let previousTask = Self.schedulingTask?.task
        let taskID = UUID()
        let task = Task { @MainActor in
            await previousTask?.value
            await self.performRescheduleAll(
                prayerEntries: prayerEntries,
                preferences: preferences,
                customAlarms: customAlarms,
                reason: reason
            )
        }
        Self.schedulingTask = (taskID, task)
        await task.value

        if Self.schedulingTask?.id == taskID {
            Self.schedulingTask = nil
        }
    }

    private func performRescheduleAll(
        prayerEntries: [[PrayerTimeEntry]],
        preferences: UserPreferences?,
        customAlarms: [CustomAlarm],
        reason: RescheduleReason
    ) async {
        // Routine rebuilds use cancelAll(), so defer them while an alarm is active.
        // Language changes use the active-alarm-safe cancellation path below.
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            let hasActiveAlarmActivity = Activity<AlarmAttributes<AdhanAlarmMetadata>>.activities.contains {
                $0.activityState == .active
            }
            if hasActiveAlarmActivity && reason != .languageChange {
                AppLogger.scheduling.info("rescheduleAll: skipped — active alarm live activity detected")
                #if canImport(FirebaseCrashlytics)
                Crashlytics.crashlytics().log("rescheduleAll: skipped — active alarm live activity")
                #endif
                return
            }
        }
        #endif

        // Routine rebuilds also respect the cooldown around a recently fired alarm.
        let now = Date()
        let recentlyFired = scheduledAlarmTimes.values.flatMap { $0 }.contains { fireTime in
            let elapsed = now.timeIntervalSince(fireTime)
            return elapsed >= -60 && elapsed < Self.alarmCooldown
        }
        if recentlyFired && reason != .languageChange {
            AppLogger.scheduling.info("rescheduleAll: skipped — in-memory cooldown active")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().log("rescheduleAll: skipped — in-memory cooldown active")
            #endif
            return
        }

        // Also check the persisted fire time (covers fresh instances, e.g. background tasks)
        if let fireTime = Constants.sharedDefaults?.object(forKey: Constants.Keys.nextAlarmFireTime) as? Date {
            let elapsed = now.timeIntervalSince(fireTime)
            if elapsed >= -60 && elapsed < Self.alarmCooldown && reason != .languageChange {
                AppLogger.scheduling.info("rescheduleAll: skipped — persisted cooldown active (fireTime=\(fireTime.formatted()))")
                #if canImport(FirebaseCrashlytics)
                Crashlytics.crashlytics().log("rescheduleAll: skipped — persisted cooldown active")
                #endif
                return
            }
        }

        let totalEntries = prayerEntries.flatMap { $0 }.count
        let scheduleStart = Date()
        AppLogger.scheduling.info("rescheduleAll: starting with \(totalEntries) entries across \(prayerEntries.count) days")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("rescheduleAll: starting with \(totalEntries) entries")
        #endif

        await performScheduling(
            prayerEntries: prayerEntries,
            preferences: preferences,
            customAlarms: customAlarms,
            preserveActiveAlarms: reason == .languageChange
        )

        let scheduleDuration = Date().timeIntervalSince(scheduleStart)
        AppLogger.scheduling.info("rescheduleAll: finished in \(String(format: "%.2f", scheduleDuration))s")
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("rescheduleAll: finished in \(String(format: "%.2f", scheduleDuration))s")
        Crashlytics.crashlytics().setCustomValue(scheduleDuration, forKey: "last_reschedule_duration_sec")
        #endif
    }

    private func performScheduling(
        prayerEntries: [[PrayerTimeEntry]],
        preferences: UserPreferences?,
        customAlarms: [CustomAlarm],
        preserveActiveAlarms: Bool
    ) async {
        // Rebuild all pending alerts. A language change may happen while an
        // AlarmKit alarm is active, so preserve active alarms in that case.
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        if preserveActiveAlarms {
            alarmManager.cancelScheduledAlarmsPreservingActive()
        } else {
            alarmManager.cancelAll()
        }
        scheduledAlarmTimes.removeAll()

        // Give iOS time to clean up cancelled notifications/alarms
        try? await Task.sleep(for: .milliseconds(100))

        var scheduledCount = 0
        let maxNotifications = Constants.NotificationBudget.maxPendingNotifications
        let now = Date()

        for dayEntries in prayerEntries {
            for entry in dayEntries {
                guard scheduledCount < maxNotifications else { break }

                let mode = notificationMode(for: entry.prayer, preferences: preferences)
                guard mode != .silent else { continue }
                let timing = alertTimingSettings(for: entry.prayer, preferences: preferences)

                if timing.shouldScheduleMainAlert && entry.adjustedTime > now {
                    switch mode {
                    case .silent:
                        break

                    case .notification:
                        let request = createNotificationRequest(for: entry, mode: .notification)
                        do {
                            try await center.add(request)
                            scheduledCount += 1
                            AppLogger.scheduling.debug("scheduled notification: \(entry.prayer.rawValue) at \(entry.adjustedTime.formatted(date: .abbreviated, time: .standard))")
                        } catch {
                            AppLogger.scheduling.error("notification failed for \(entry.prayer.rawValue): \(error.localizedDescription)")
                            #if canImport(FirebaseCrashlytics)
                            Crashlytics.crashlytics().record(error: error, userInfo: ["context": "schedule_notification", "prayer": entry.prayer.rawValue])
                            #endif
                        }

                    case .alarm:
                        let audio = alarmAudio(for: entry.prayer, preferences: preferences)
                        do {
                            try await alarmManager.scheduleAlarm(
                                for: entry.prayer,
                                at: entry.adjustedTime,
                                audioFileName: audio
                            )
                            scheduledAlarmTimes[entry.prayer.rawValue, default: []].append(entry.adjustedTime)
                            scheduledCount += 1
                        } catch {
                            AppLogger.scheduling.error("alarm failed for \(entry.prayer.rawValue) at \(entry.adjustedTime.formatted()): \(error.localizedDescription)")
                            #if canImport(FirebaseCrashlytics)
                            Crashlytics.crashlytics().record(error: error, userInfo: ["context": "schedule_alarm", "prayer": entry.prayer.rawValue])
                            #endif
                        }
                    }
                }

                if timing.isOffsetAlertEnabled {
                    let offsetTime = timing.offsetFireDate(relativeTo: entry.adjustedTime)
                    guard offsetTime > now else { continue }

                    switch mode {
                    case .silent:
                        break
                    case .notification:
                        guard scheduledCount < maxNotifications else { break }
                        let request = createOffsetNotificationRequest(
                            for: entry,
                            timing: timing,
                            at: offsetTime
                        )
                        do {
                            try await center.add(request)
                            scheduledCount += 1
                        } catch { /* skip */ }

                    case .alarm:
                        do {
                            try await alarmManager.schedulePreAlarm(
                                for: entry.prayer,
                                at: offsetTime,
                                offsetMinutes: timing.offsetMinutes
                            )
                            scheduledAlarmTimes["\(entry.prayer.rawValue)_offset", default: []].append(offsetTime)
                        } catch { /* skip */ }
                    }
                }

            }
        }

        AppLogger.scheduling.info("rescheduleAll: scheduled \(scheduledCount) prayer alarms/notifications")

        // Schedule custom alarms
        await scheduleCustomAlarms(customAlarms: customAlarms)

        // Update next scheduled alarm time from all prayer entries (today + future days)
        let allEntries = prayerEntries.flatMap { $0 }
        refreshNextAlarmTime(prayerEntries: allEntries, customAlarms: customAlarms, preferences: preferences)

        // Persist the nearest alarm fire time so background tasks can respect the cooldown
        if let next = nextScheduledAlarmTime {
            Constants.sharedDefaults?.set(next, forKey: Constants.Keys.nextAlarmFireTime)
            AppLogger.scheduling.info("rescheduleAll: done. Next alarm: \(self.nextScheduledName ?? "?") at \(next.formatted(date: .abbreviated, time: .standard))")
        } else {
            AppLogger.scheduling.info("rescheduleAll: done. No upcoming alarms.")
        }

        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(scheduledCount, forKey: "last_scheduled_count")
        if let next = nextScheduledAlarmTime {
            Crashlytics.crashlytics().setCustomValue(next.timeIntervalSince1970, forKey: "next_alarm_timestamp")
            Crashlytics.crashlytics().setCustomValue(nextScheduledName ?? "unknown", forKey: "next_alarm_name")
        }
        #endif
    }

    /// Compute the soonest upcoming notification or alarm from prayer entries and custom alarms.
    func refreshNextAlarmTime(
        prayerEntries: [PrayerTimeEntry] = [],
        customAlarms: [CustomAlarm] = [],
        preferences: UserPreferences? = nil,
        now: Date = Date()
    ) {
        var earliest: Date? = nil
        var earliestIsAlarm = false
        var earliestName: String? = nil

        func consider(_ time: Date, isAlarm: Bool, name: String) {
            guard time > now, earliest == nil || time < earliest! else { return }
            earliest = time
            earliestIsAlarm = isAlarm
            earliestName = name
        }

        // Check prayer entries (main + offset alert)
        for entry in prayerEntries {
            let time = entry.adjustedTime
            let mode = notificationMode(for: entry.prayer, preferences: preferences)
            guard mode != .silent else { continue }
            let timing = alertTimingSettings(for: entry.prayer, preferences: preferences)

            if timing.shouldScheduleMainAlert {
                consider(time, isAlarm: mode == .alarm, name: entry.prayer.localizedName)
            }

            if timing.isOffsetAlertEnabled {
                consider(
                    timing.offsetFireDate(relativeTo: time),
                    isAlarm: mode == .alarm,
                    name: offsetAlertName(subject: entry.prayer.localizedName, offsetMinutes: timing.offsetMinutes)
                )
            }
        }

        // Check enabled custom alarms (main + offset alert)
        let calendar = Calendar.current
        for alarm in customAlarms where alarm.isEnabled {
            let mode = alarm.mode
            guard mode != .silent else { continue }
            let timing = alarm.alertTimingSettings
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            comps.second = 0
            guard let todayAlarmTime = calendar.date(from: comps) else { continue }

            if timing.shouldScheduleMainAlert {
                let nextMainTime = todayAlarmTime > now
                    ? todayAlarmTime
                    : calendar.date(byAdding: .day, value: 1, to: todayAlarmTime)
                if let nextMainTime {
                    consider(nextMainTime, isAlarm: mode == .alarm, name: alarm.title)
                }
            }

            if timing.isOffsetAlertEnabled {
                var nextOffsetTime = timing.offsetFireDate(relativeTo: todayAlarmTime)
                if nextOffsetTime <= now,
                   let tomorrowAlarmTime = calendar.date(byAdding: .day, value: 1, to: todayAlarmTime) {
                    nextOffsetTime = timing.offsetFireDate(relativeTo: tomorrowAlarmTime)
                }
                consider(
                    nextOffsetTime,
                    isAlarm: mode == .alarm,
                    name: offsetAlertName(subject: alarm.title, offsetMinutes: timing.offsetMinutes)
                )
            }
        }

        nextScheduledAlarmTime = earliest
        nextScheduledIsAlarm = earliestIsAlarm
        nextScheduledName = earliestName
    }

    // MARK: - Custom Alarm Scheduling

    private func scheduleCustomAlarms(customAlarms: [CustomAlarm]) async {
        let calendar = Calendar.current
        let now = Date()
        let daysAhead = Constants.NotificationBudget.daysToScheduleAhead

        for alarm in customAlarms {
            guard alarm.isEnabled else { continue }

            let mode = alarm.mode
            guard mode != .silent else { continue }
            let timing = alarm.alertTimingSettings

            for dayOffset in 0..<daysAhead {
                guard let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
                components.hour = alarm.hour
                components.minute = alarm.minute
                components.second = 0

                guard let alarmTime = calendar.date(from: components) else { continue }

                if timing.shouldScheduleMainAlert && alarmTime > now {
                    switch mode {
                    case .silent:
                        break

                    case .notification:
                        let request = createCustomNotificationRequest(alarm: alarm, at: alarmTime, dayOffset: dayOffset)
                        do {
                            try await UNUserNotificationCenter.current().add(request)
                        } catch { /* main notification failed; still attempt offset alert below */ }

                    case .alarm:
                        let audioPath: String? = alarm.alarmAudio.isEmpty
                            ? nil
                            : AdhanAudioCatalog.alarmSoundPath(forID: alarm.alarmAudio)
                        do {
                            try await alarmManager.scheduleCustomAlarm(
                                id: alarm.id,
                                title: alarm.title,
                                at: alarmTime,
                                audioFileName: audioPath
                            )
                            scheduledAlarmTimes["custom_\(alarm.id.uuidString)", default: []].append(alarmTime)
                        } catch { /* main alarm failed; still attempt offset alert below */ }
                    }
                }

                if timing.isOffsetAlertEnabled {
                    let offsetTime = timing.offsetFireDate(relativeTo: alarmTime)
                    guard offsetTime > now else { continue }

                    switch mode {
                    case .silent:
                        break
                    case .notification:
                        let request = createCustomOffsetNotificationRequest(
                            alarm: alarm,
                            at: offsetTime,
                            timing: timing,
                            dayOffset: dayOffset
                        )
                        do {
                            try await UNUserNotificationCenter.current().add(request)
                        } catch { /* skip */ }

                    case .alarm:
                        do {
                            try await alarmManager.scheduleCustomPreAlarm(
                                id: alarm.id,
                                title: alarm.title,
                                at: offsetTime,
                                offsetMinutes: timing.offsetMinutes
                            )
                            scheduledAlarmTimes["custom_\(alarm.id.uuidString)_offset", default: []].append(offsetTime)
                        } catch { /* skip */ }
                    }
                }
            }
        }
    }

    private func createCustomOffsetNotificationRequest(
        alarm: CustomAlarm,
        at time: Date,
        timing: AlertTimingSettings,
        dayOffset: Int
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        let bundle = LanguageManager.shared.bundle
        content.title = timing.localizedAlertTitle(subject: alarm.title, bundle: bundle)
        content.body = offsetNotificationBody(subject: alarm.title, timing: timing, bundle: bundle)
        content.categoryIdentifier = "CUSTOM_PRE_ALARM"
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: time
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let dateString = formatDateForId(time)
        let identifier = "custom_\(alarm.id.uuidString)_\(dateString)_d\(dayOffset)_prealarm"

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func createCustomNotificationRequest(
        alarm: CustomAlarm,
        at time: Date,
        dayOffset: Int
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = alarm.title
        content.body = String(localized: "Custom alarm: \(alarm.title)", bundle: LanguageManager.shared.bundle)
        content.categoryIdentifier = "CUSTOM_ALARM"
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: time
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let dateString = formatDateForId(time)
        let identifier = "custom_\(alarm.id.uuidString)_\(dateString)_d\(dayOffset)"

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    // MARK: - Test Fire

    /// Fire a test notification/alarm in 5 seconds based on the given mode.
    func fireTest(mode: PrayerNotificationMode) async -> String {
        switch mode {
        case .silent:
            return "Silent mode — nothing to fire"

        case .notification:
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Test Prayer", bundle: LanguageManager.shared.bundle)
            content.body = String(localized: "This is a test notification with sound", bundle: LanguageManager.shared.bundle)
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: "test_notif_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
            do {
                try await UNUserNotificationCenter.current().add(request)
                return "Notification scheduled — fires in 5s"
            } catch {
                return "Error: \(error.localizedDescription)"
            }

        case .alarm:
            await alarmManager.requestAuthorization()
            guard alarmManager.isAuthorized else {
                return "Alarm not authorized. Auth state: \(alarmManager.authError ?? "denied"). Check Settings > Apps > Adhan."
            }
            let testTime = Date().addingTimeInterval(5)
            do {
                try await alarmManager.scheduleAlarm(
                    for: .fajr,
                    at: testTime
                )
                return "Alarm scheduled — fires in 5s"
            } catch {
                return "Alarm error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Notification Creation

    private func createNotificationRequest(
        for entry: PrayerTimeEntry,
        mode: PrayerNotificationMode
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = entry.prayer.localizedName
        content.body = String(
            localized: "It's time for \(entry.prayer.localizedName) prayer",
            bundle: LanguageManager.shared.bundle
        )
        content.categoryIdentifier = "PRAYER_TIME"

        switch mode {
        case .notification:
            content.sound = .default
        case .silent, .alarm:
            break
        }

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: entry.adjustedTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let dateString = formatDateForId(entry.adjustedTime)
        let identifier = "\(entry.prayer.rawValue)_\(dateString)_prayer"

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }


    // MARK: - Preference Helpers

    private func notificationMode(for prayer: PrayerName, preferences: UserPreferences?) -> PrayerNotificationMode {
        guard let prefs = preferences else {
            return prayer == .tahajjud ? .silent : .notification
        }
        let raw: String
        switch prayer {
        case .tahajjud: raw = prefs.tahajjudNotificationMode
        case .fajr: raw = prefs.fajrNotificationMode
        case .dhuhr: raw = prefs.dhuhrNotificationMode
        case .asr: raw = prefs.asrNotificationMode
        case .maghrib: raw = prefs.maghribNotificationMode
        case .isha: raw = prefs.ishaNotificationMode
        }
        let mode = PrayerNotificationMode(rawValue: raw) ?? .notification
        // On iOS < 26 alarm mode is unavailable, fall back to notification
        if mode == .alarm && !AdhanAlarmManager.isAlarmSupported {
            return .notification
        }
        return mode
    }

    private func alarmAudio(for prayer: PrayerName, preferences: UserPreferences?) -> String? {
        guard let prefs = preferences else { return nil }
        let value: String
        switch prayer {
        case .tahajjud: value = prefs.tahajjudAlarmAudio
        case .fajr: value = prefs.fajrAlarmAudio
        case .dhuhr: value = prefs.dhuhrAlarmAudio
        case .asr: value = prefs.asrAlarmAudio
        case .maghrib: value = prefs.maghribAlarmAudio
        case .isha: value = prefs.ishaAlarmAudio
        }
        guard !value.isEmpty else { return nil }
        return AdhanAudioCatalog.alarmSoundPath(forID: value)
    }

    private func alertTimingSettings(
        for prayer: PrayerName,
        preferences: UserPreferences?
    ) -> AlertTimingSettings {
        preferences?.alertTimingSettings(for: prayer) ?? AlertTimingSettings()
    }

    private func createOffsetNotificationRequest(
        for entry: PrayerTimeEntry,
        timing: AlertTimingSettings,
        at offsetTime: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        let bundle = LanguageManager.shared.bundle
        content.title = timing.localizedAlertTitle(subject: entry.prayer.localizedName, bundle: bundle)
        content.body = offsetNotificationBody(
            subject: entry.prayer.localizedName,
            timing: timing,
            bundle: bundle
        )
        content.categoryIdentifier = "PRAYER_PRE_ALARM"
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: offsetTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let dateString = formatDateForId(entry.adjustedTime)
        let identifier = "\(entry.prayer.rawValue)_\(dateString)_prealarm"

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func offsetNotificationBody(
        subject: String,
        timing: AlertTimingSettings,
        bundle: Bundle
    ) -> String {
        if timing.offsetMinutes < 0 {
            return String(localized: "Prepare for \(subject)", bundle: bundle)
        } else if timing.offsetMinutes > 0 {
            return String(
                localized: "The scheduled time for \(subject) was \(timing.offsetMinutes) min ago",
                bundle: bundle
            )
        }
        return String(localized: "It's time for \(subject)", bundle: bundle)
    }

    private func offsetAlertName(subject: String, offsetMinutes: Int) -> String {
        let bundle = LanguageManager.shared.bundle
        if offsetMinutes < 0 {
            return String(localized: "Before \(subject)", bundle: bundle)
        } else if offsetMinutes > 0 {
            return String(localized: "After \(subject)", bundle: bundle)
        }
        return subject
    }

    private func formatDateForId(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
