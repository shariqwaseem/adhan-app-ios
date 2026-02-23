import Foundation
import UserNotifications
import Observation

@Observable
@MainActor
final class NotificationScheduler {
    var isPermissionGranted: Bool = false
    private var isScheduling: Bool = false

    var alarmManager = AthanAlarmManager()

    func requestPermission() async {
        do {
            isPermissionGranted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            isPermissionGranted = false
        }
        await alarmManager.requestAuthorization()
    }

    func rescheduleAll(
        prayerEntries: [[PrayerTimeEntry]],
        preferences: UserPreferences?
    ) async {
        guard !isScheduling else { return }
        isScheduling = true
        defer { isScheduling = false }

        // Nuclear clear: remove all pending notifications and alarms
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        alarmManager.cancelAll()

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

                case .vibrate:
                    let request = createNotificationRequest(for: entry, mode: .vibrate)
                    do {
                        try await center.add(request)
                        scheduledCount += 1
                    } catch { continue }

                case .notification:
                    let request = createNotificationRequest(for: entry, mode: .notification)
                    do {
                        try await center.add(request)
                        scheduledCount += 1
                    } catch { continue }

                case .alarm:
                    let offset = alarmOffset(for: entry.prayer, preferences: preferences)
                    do {
                        try await alarmManager.scheduleAlarm(
                            for: entry.prayer,
                            at: entry.adjustedTime,
                            offsetMinutes: offset
                        )
                        scheduledCount += 1
                    } catch { continue }
                }

                // Pre-reminder (for non-silent, non-alarm modes)
                if mode == .vibrate || mode == .notification {
                    let preMinutes = preReminderMinutes(for: entry.prayer, preferences: preferences)
                    if preMinutes > 0, scheduledCount < maxNotifications {
                        if let preRequest = createPreReminderRequest(for: entry, minutesBefore: preMinutes) {
                            do {
                                try await center.add(preRequest)
                                scheduledCount += 1
                            } catch { continue }
                        }
                    }
                }
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
            localized: "It's time for \(entry.prayer.localizedName) prayer"
        )
        content.categoryIdentifier = "PRAYER_TIME"

        switch mode {
        case .notification:
            content.sound = .default
        case .vibrate:
            content.sound = nil
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

    private func createPreReminderRequest(
        for entry: PrayerTimeEntry,
        minutesBefore: Int
    ) -> UNNotificationRequest? {
        guard let reminderTime = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: entry.adjustedTime),
              reminderTime > Date() else { return nil }

        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "\(entry.prayer.localizedName) in \(minutesBefore) minutes"
        )
        content.body = String(
            localized: "Prepare for \(entry.prayer.localizedName) prayer"
        )
        content.sound = .default
        content.categoryIdentifier = "PRAYER_REMINDER"

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminderTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let dateString = formatDateForId(entry.adjustedTime)
        let identifier = "\(entry.prayer.rawValue)_\(dateString)_reminder"

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    // MARK: - Preference Helpers

    private func notificationMode(for prayer: PrayerName, preferences: UserPreferences?) -> PrayerNotificationMode {
        guard let prefs = preferences else { return .notification }
        let raw: String
        switch prayer {
        case .fajr: raw = prefs.fajrNotificationMode
        case .sunrise: raw = prefs.sunriseNotificationMode
        case .dhuhr: raw = prefs.dhuhrNotificationMode
        case .asr: raw = prefs.asrNotificationMode
        case .maghrib: raw = prefs.maghribNotificationMode
        case .isha: raw = prefs.ishaNotificationMode
        }
        return PrayerNotificationMode(rawValue: raw) ?? .notification
    }

    private func alarmOffset(for prayer: PrayerName, preferences: UserPreferences?) -> Int {
        guard let prefs = preferences else { return 0 }
        switch prayer {
        case .fajr: return prefs.fajrAlarmOffset
        case .sunrise: return 0
        case .dhuhr: return prefs.dhuhrAlarmOffset
        case .asr: return prefs.asrAlarmOffset
        case .maghrib: return prefs.maghribAlarmOffset
        case .isha: return prefs.ishaAlarmOffset
        }
    }

    private func preReminderMinutes(for prayer: PrayerName, preferences: UserPreferences?) -> Int {
        guard let prefs = preferences else { return 0 }
        switch prayer {
        case .fajr: return prefs.fajrPreReminder
        case .sunrise: return 0
        case .dhuhr: return prefs.dhuhrPreReminder
        case .asr: return prefs.asrPreReminder
        case .maghrib: return prefs.maghribPreReminder
        case .isha: return prefs.ishaPreReminder
        }
    }

    private func formatDateForId(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
