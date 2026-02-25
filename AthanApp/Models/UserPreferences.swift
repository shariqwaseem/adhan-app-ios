import Foundation
import SwiftData

@Model
final class UserPreferences {
    var calculationMethodRawValue: String = CalculationMethodInfo.MuslimWorldLeague.rawValue
    var asrJuristicMethodRawValue: String = AsrJuristicMethod.standard.rawValue
    var highLatitudeRuleRawValue: String = HighLatitudeRuleOption.middleOfTheNight.rawValue

    // Per-prayer notification mode: silent / notification / alarm
    var tahajjudNotificationMode: String = PrayerNotificationMode.silent.rawValue
    var fajrNotificationMode: String = UserPreferences.defaultAlarmMode
    var dhuhrNotificationMode: String = UserPreferences.defaultAlarmMode
    var asrNotificationMode: String = UserPreferences.defaultAlarmMode
    var maghribNotificationMode: String = UserPreferences.defaultAlarmMode
    var ishaNotificationMode: String = UserPreferences.defaultAlarmMode

    // Per-prayer alarm audio selection (filename without extension, "" = system default)
    var tahajjudAlarmAudio: String = "Adhan-Makkah-New"
    var fajrAlarmAudio: String = "Adhan-Makkah-New"
    var dhuhrAlarmAudio: String = "Adhan-Makkah-New"
    var asrAlarmAudio: String = "Adhan-Makkah-New"
    var maghribAlarmAudio: String = "Adhan-Makkah-New"
    var ishaAlarmAudio: String = "Adhan-Makkah-New"

    // Pre-alarm: minutes before prayer (0 = disabled, 10–120)
    var fajrPreAlarmMinutes: Int = 0
    var tahajjudPreAlarmMinutes: Int = 0

    // Ramadan
    var ramadanAutoDetect: Bool = true
    var ramadanManualOverride: Bool = false
    var suhoorBufferMinutes: Int = 10

    /// On iOS < 26 alarm mode is unavailable, fall back to notification.
    private static var defaultAlarmMode: String {
        if AthanAlarmManager.isAlarmSupported {
            return PrayerNotificationMode.alarm.rawValue
        }
        return PrayerNotificationMode.notification.rawValue
    }

    init() {}
}
