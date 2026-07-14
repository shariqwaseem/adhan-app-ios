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
    // Legacy pre-alarm value, retained so existing stores migrate without losing settings.
    var preAlarmMinutes: Int = 0
    var alertOffsetMinutes: Int?
    var offsetAlertEnabled: Bool?
    var mainAlertEnabled: Bool?
    var createdAt: Date = Date()

    init(
        title: String = "",
        hour: Int = 5,
        minute: Int = 0,
        notificationMode: PrayerNotificationMode = .alarm,
        alarmAudio: String = "",
        isEnabled: Bool = true,
        preAlarmMinutes: Int = 0,
        alertTimingSettings: AlertTimingSettings? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.hour = hour
        self.minute = minute
        self.notificationMode = notificationMode.rawValue
        self.alarmAudio = alarmAudio
        self.isEnabled = isEnabled
        self.preAlarmMinutes = preAlarmMinutes
        if let alertTimingSettings {
            let normalized = alertTimingSettings.normalized
            self.alertOffsetMinutes = normalized.offsetMinutes
            self.offsetAlertEnabled = normalized.isOffsetAlertEnabled
            self.mainAlertEnabled = normalized.isMainAlertEnabled
            self.preAlarmMinutes = 0
        }
        self.createdAt = Date()
    }

    var mode: PrayerNotificationMode {
        get { PrayerNotificationMode(rawValue: notificationMode) ?? .alarm }
        set { notificationMode = newValue.rawValue }
    }

    var alertTimingSettings: AlertTimingSettings {
        get {
            if alertOffsetMinutes != nil || offsetAlertEnabled != nil || mainAlertEnabled != nil {
                return AlertTimingSettings(
                    offsetMinutes: alertOffsetMinutes ?? AlertTimingSettings.defaultOffsetMinutes,
                    isOffsetAlertEnabled: offsetAlertEnabled ?? false,
                    isMainAlertEnabled: mainAlertEnabled ?? true
                )
            }

            return AlertTimingSettings(
                offsetMinutes: preAlarmMinutes == 0
                    ? AlertTimingSettings.defaultOffsetMinutes
                    : -preAlarmMinutes,
                isOffsetAlertEnabled: preAlarmMinutes != 0,
                isMainAlertEnabled: true
            )
        }
        set {
            let normalized = newValue.normalized
            alertOffsetMinutes = normalized.offsetMinutes
            offsetAlertEnabled = normalized.isOffsetAlertEnabled
            mainAlertEnabled = normalized.isMainAlertEnabled
            preAlarmMinutes = 0
        }
    }
}
