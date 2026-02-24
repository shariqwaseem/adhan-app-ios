import Foundation
import SwiftData

@Model
final class CustomAlarm {
    var id: UUID = UUID()
    var title: String = ""
    var hour: Int = 5
    var minute: Int = 0
    var notificationMode: String = PrayerNotificationMode.alarm.rawValue
    var alarmAudio: String = ""
    var isEnabled: Bool = true
    var createdAt: Date = Date()

    init(
        title: String = "",
        hour: Int = 5,
        minute: Int = 0,
        notificationMode: PrayerNotificationMode = .alarm,
        alarmAudio: String = "",
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.hour = hour
        self.minute = minute
        self.notificationMode = notificationMode.rawValue
        self.alarmAudio = alarmAudio
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }

    var mode: PrayerNotificationMode {
        get { PrayerNotificationMode(rawValue: notificationMode) ?? .alarm }
        set { notificationMode = newValue.rawValue }
    }
}
