import Foundation
import UserNotifications
import Observation

@Observable
@MainActor
final class NotificationScheduler {
    var isPermissionGranted: Bool = false
    private var isScheduling: Bool = false
    var nextScheduledAlarmTime: Date? = nil
    var nextScheduledIsAlarm: Bool = false
    private var scheduledAlarmTimes: [String: [Date]] = [:]  // tracking AlarmKit-scheduled fire dates

    var alarmManager = AthanAlarmManager()

    func requestPermission() async {
        do {
            isPermissionGranted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            isPermissionGranted = false
        }
        if AthanAlarmManager.isAlarmSupported {
            await alarmManager.requestAuthorization()
        }
    }

    private static let alarmCooldown: TimeInterval = 600 // 10 minutes

    func rescheduleAll(
        prayerEntries: [[PrayerTimeEntry]],
        preferences: UserPreferences?,
        customAlarms: [CustomAlarm] = []
    ) async {
        guard !isScheduling else { return }

        // Don't reschedule if an alarm fired (or was due) within the last 10 minutes —
        // cancelAll() would silence a currently-ringing alarm.
        let now = Date()
        let recentlyFired = scheduledAlarmTimes.values.flatMap { $0 }.contains { fireTime in
            let elapsed = now.timeIntervalSince(fireTime)
            return elapsed >= 0 && elapsed < Self.alarmCooldown
        }
        if recentlyFired { return }

        // Also check the persisted fire time (covers fresh instances, e.g. background tasks)
        if let fireTime = Constants.sharedDefaults?.object(forKey: Constants.Keys.nextAlarmFireTime) as? Date {
            let elapsed = now.timeIntervalSince(fireTime)
            if elapsed >= 0 && elapsed < Self.alarmCooldown { return }
        }

        isScheduling = true
        defer { isScheduling = false }

        // Nuclear clear: remove all pending notifications and alarms
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        alarmManager.cancelAll()
        scheduledAlarmTimes.removeAll()

        var scheduledCount = 0
        let maxNotifications = Constants.NotificationBudget.maxPendingNotifications

        for dayEntries in prayerEntries {
            for entry in dayEntries {
                guard scheduledCount < maxNotifications else { break }
                guard entry.adjustedTime > Date() else { continue }

                let mode = notificationMode(for: entry.prayer, preferences: preferences)

                switch mode {
                case .silent:
                    continue

                case .notification:
                    let request = createNotificationRequest(for: entry, mode: .notification)
                    do {
                        try await center.add(request)
                        scheduledCount += 1
                    } catch { /* main notification failed; still attempt pre-alarm below */ }

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
                    } catch { /* main alarm failed; still attempt pre-alarm below */ }
                }

                // Pre-alarm scheduling
                let preMinutes = preAlarmMinutes(for: entry.prayer, preferences: preferences)
                if preMinutes > 0 {
                    let preAlarmTime = entry.adjustedTime.addingTimeInterval(-Double(preMinutes) * 60)
                    guard preAlarmTime > Date() else { continue }

                    switch mode {
                    case .silent:
                        break
                    case .notification:
                        guard scheduledCount < maxNotifications else { break }
                        let request = createPreAlarmNotificationRequest(
                            for: entry,
                            minutesBefore: preMinutes
                        )
                        do {
                            try await center.add(request)
                            scheduledCount += 1
                        } catch { /* skip */ }

                    case .alarm:
                        do {
                            try await alarmManager.schedulePreAlarm(
                                for: entry.prayer,
                                at: preAlarmTime,
                                minutesBefore: preMinutes
                            )
                            scheduledAlarmTimes["\(entry.prayer.rawValue)_pre", default: []].append(preAlarmTime)
                        } catch { /* skip */ }
                    }
                }

            }
        }

        // Schedule custom alarms
        await scheduleCustomAlarms(customAlarms: customAlarms)

        // Update next scheduled alarm time from the system
        await refreshNextAlarmTime()

        // Persist the nearest alarm fire time so background tasks can respect the cooldown
        if let next = nextScheduledAlarmTime {
            Constants.sharedDefaults?.set(next, forKey: Constants.Keys.nextAlarmFireTime)
        }
    }

    /// Query all pending notifications to find the soonest fire date.
    func refreshNextAlarmTime() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let now = Date()
        var earliest: Date? = nil
        var earliestIsAlarm = false

        for request in pending {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let fireDate = trigger.nextTriggerDate(),
               fireDate > now {
                if earliest == nil || fireDate < earliest! {
                    earliest = fireDate
                    earliestIsAlarm = false
                }
            }
        }

        // Also include AlarmKit-scheduled times we tracked ourselves
        for (_, times) in scheduledAlarmTimes {
            for time in times where time > now {
                if earliest == nil || time < earliest! {
                    earliest = time
                    earliestIsAlarm = true
                }
            }
        }

        nextScheduledAlarmTime = earliest
        nextScheduledIsAlarm = earliestIsAlarm
    }

    // MARK: - Custom Alarm Scheduling

    private func scheduleCustomAlarms(customAlarms: [CustomAlarm]) async {
        let calendar = Calendar.current
        let now = Date()
        let daysAhead = Constants.NotificationBudget.daysToScheduleAhead

        for alarm in customAlarms {
            guard alarm.isEnabled else { continue }

            let mode = alarm.mode

            for dayOffset in 0..<daysAhead {
                guard let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
                components.hour = alarm.hour
                components.minute = alarm.minute
                components.second = 0

                guard let alarmTime = calendar.date(from: components),
                      alarmTime > now else { continue }

                switch mode {
                case .silent:
                    continue

                case .notification:
                    let request = createCustomNotificationRequest(alarm: alarm, at: alarmTime, dayOffset: dayOffset)
                    do {
                        try await UNUserNotificationCenter.current().add(request)
                    } catch { /* main notification failed; still attempt pre-alarm below */ }

                case .alarm:
                    let audioPath: String? = alarm.alarmAudio.isEmpty
                        ? nil
                        : AdhanAudioCatalog.bundleRelativePath(forID: alarm.alarmAudio)
                    do {
                        try await alarmManager.scheduleCustomAlarm(
                            id: alarm.id,
                            title: alarm.title,
                            at: alarmTime,
                            audioFileName: audioPath
                        )
                        scheduledAlarmTimes["custom_\(alarm.id.uuidString)", default: []].append(alarmTime)
                    } catch { /* main alarm failed; still attempt pre-alarm below */ }
                }

                // Pre-alarm scheduling for custom alarms
                let preMinutes = alarm.preAlarmMinutes
                if preMinutes > 0 {
                    let preAlarmTime = alarmTime.addingTimeInterval(-Double(preMinutes) * 60)
                    guard preAlarmTime > now else { continue }

                    switch mode {
                    case .silent:
                        break
                    case .notification:
                        let request = createCustomPreAlarmNotificationRequest(
                            alarm: alarm,
                            at: preAlarmTime,
                            minutesBefore: preMinutes,
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
                                at: preAlarmTime,
                                minutesBefore: preMinutes
                            )
                            scheduledAlarmTimes["custom_\(alarm.id.uuidString)_pre", default: []].append(preAlarmTime)
                        } catch { /* skip */ }
                    }
                }
            }
        }
    }

    private func createCustomPreAlarmNotificationRequest(
        alarm: CustomAlarm,
        at time: Date,
        minutesBefore: Int,
        dayOffset: Int
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(alarm.title) in \(minutesBefore) min", bundle: LanguageManager.shared.bundle)
        content.body = String(localized: "Prepare for \(alarm.title)", bundle: LanguageManager.shared.bundle)
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
                return "Alarm not authorized. Auth state: \(alarmManager.authError ?? "denied"). Check Settings > Apps > Athan."
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
        if mode == .alarm && !AthanAlarmManager.isAlarmSupported {
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
        return AdhanAudioCatalog.bundleRelativePath(forID: value)
    }

    private func preAlarmMinutes(for prayer: PrayerName, preferences: UserPreferences?) -> Int {
        guard let prefs = preferences else { return 0 }
        switch prayer {
        case .tahajjud: return prefs.tahajjudPreAlarmMinutes
        case .fajr: return prefs.fajrPreAlarmMinutes
        case .dhuhr: return prefs.dhuhrPreAlarmMinutes
        case .asr: return prefs.asrPreAlarmMinutes
        case .maghrib: return prefs.maghribPreAlarmMinutes
        case .isha: return prefs.ishaPreAlarmMinutes
        }
    }

    private func createPreAlarmNotificationRequest(
        for entry: PrayerTimeEntry,
        minutesBefore: Int
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(entry.prayer.localizedName) in \(minutesBefore) min", bundle: LanguageManager.shared.bundle)
        content.body = String(
            localized: "Prepare for \(entry.prayer.localizedName) prayer",
            bundle: LanguageManager.shared.bundle
        )
        content.categoryIdentifier = "PRAYER_PRE_ALARM"
        content.sound = .default

        let preAlarmTime = entry.adjustedTime.addingTimeInterval(-Double(minutesBefore) * 60)
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: preAlarmTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let dateString = formatDateForId(entry.adjustedTime)
        let identifier = "\(entry.prayer.rawValue)_\(dateString)_prealarm"

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func formatDateForId(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
