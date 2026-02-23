import Foundation
import SwiftData

@Model
final class UserPreferences {
    var calculationMethodRawValue: String = CalculationMethodInfo.MuslimWorldLeague.rawValue
    var asrJuristicMethodRawValue: String = AsrJuristicMethod.standard.rawValue
    var highLatitudeRuleRawValue: String = HighLatitudeRuleOption.middleOfTheNight.rawValue

    // Per-prayer notification mode: silent / vibrate / notification / alarm
    var tahajjudNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var fajrNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var dhuhrNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var asrNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var maghribNotificationMode: String = PrayerNotificationMode.notification.rawValue
    var ishaNotificationMode: String = PrayerNotificationMode.notification.rawValue

    // Alarm time offset (minutes before prayer time, 0 = at prayer time)
    // Only used when mode is .alarm
    var tahajjudAlarmOffset: Int = 0
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
