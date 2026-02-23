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

            }
        }
    }

    // MARK: - Test Fire

    /// Fire a test notification/alarm in 5 seconds based on the given mode.
    func fireTest(mode: PrayerNotificationMode) async -> String {
        switch mode {
        case .silent:
            return "Silent mode — nothing to fire"

        case .notification:
            let content = UNMutableNotificationContent()
            content.title = "Test Prayer"
            content.body = "This is a test notification with sound"
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
            // Request authorization first
            await alarmManager.requestAuthorization()
            guard alarmManager.isAuthorized else {
                return "Alarm not authorized. Auth state: \(alarmManager.authError ?? "denied"). Check Settings > Apps > Athan."
            }
            let testTime = Date().addingTimeInterval(5)
            do {
                try await alarmManager.scheduleAlarm(
                    for: .fajr,
                    at: testTime,
                    offsetMinutes: 0
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
            localized: "It's time for \(entry.prayer.localizedName) prayer"
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
        guard let prefs = preferences else { return .notification }
        let raw: String
        switch prayer {
        case .tahajjud: raw = prefs.tahajjudNotificationMode
        case .fajr: raw = prefs.fajrNotificationMode
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
        case .tahajjud: return prefs.tahajjudAlarmOffset
        case .fajr: return prefs.fajrAlarmOffset
        case .dhuhr: return prefs.dhuhrAlarmOffset
        case .asr: return prefs.asrAlarmOffset
        case .maghrib: return prefs.maghribAlarmOffset
        case .isha: return prefs.ishaAlarmOffset
        }
    }

    private func formatDateForId(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
