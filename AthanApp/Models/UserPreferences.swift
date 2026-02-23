import Foundation
import SwiftData

@Model
final class UserPreferences {
    var calculationMethodRawValue: String = CalculationMethodInfo.MuslimWorldLeague.rawValue
    var asrJuristicMethodRawValue: String = AsrJuristicMethod.standard.rawValue
    var highLatitudeRuleRawValue: String = HighLatitudeRuleOption.middleOfTheNight.rawValue

    // Per-prayer notification mode: silent / vibrate / notification / alarm
    var fajrNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var sunriseNotificationMode: String = PrayerNotificationMode.silent.rawValue
    var dhuhrNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var asrNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var maghribNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var ishaNotificationMode: String = PrayerNotificationMode.notification.rawValue

    // Per-prayer manual time adjustments (minutes)
    var fajrManualAdjustment: Int = 0
    var sunriseManualAdjustment: Int = 0
    var dhuhrManualAdjustment: Int = 0
    var asrManualAdjustment: Int = 0
    var maghribManualAdjustment: Int = 0
    var ishaManualAdjustment: Int = 0

    // Pre-reminder (minutes before)
    var fajrPreReminder: Int = 0
    var dhuhrPreReminder: Int = 0
    var asrPreReminder: Int = 0
    var maghribPreReminder: Int = 0
    var ishaPreReminder: Int = 0

    // Sound names for notification mode
    var fajrSoundName: String = "default"
    var dhuhrSoundName: String = "default"
    var asrSoundName: String = "default"
    var maghribSoundName: String = "default"
    var ishaSoundName: String = "default"

    // Alarm time offset (minutes before prayer time, 0 = at prayer time)
    // Only used when mode is .alarm
    var fajrAlarmOffset: Int = 0
    var dhuhrAlarmOffset: Int = 0
    var asrAlarmOffset: Int = 0
    var maghribAlarmOffset: Int = 0
    var ishaAlarmOffset: Int = 0

    // Ramadan
    var ramadanAutoDetect: Bool = true
    var ramadanManualOverride: Bool = false
    var suhoorBufferMinutes: Int = 10

    init() {}
}
