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

    // Per-prayer alarm audio selection (filename without extension, "" = system default)
    var tahajjudAlarmAudio: String = ""
    var fajrAlarmAudio: String = ""
    var dhuhrAlarmAudio: String = ""
    var asrAlarmAudio: String = ""
    var maghribAlarmAudio: String = ""
    var ishaAlarmAudio: String = ""

    // Pre-alarm: minutes before prayer (0 = disabled, 10–120)
    var fajrPreAlarmMinutes: Int = 0
    var tahajjudPreAlarmMinutes: Int = 0

    // Ramadan
    var ramadanAutoDetect: Bool = true
    var ramadanManualOverride: Bool = false
    var suhoorBufferMinutes: Int = 10

    init() {}
}
