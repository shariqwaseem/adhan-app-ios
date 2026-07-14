import Foundation
import SwiftData

struct AlertTimingSettings: Codable, Equatable {
    static let availableOffsetsMinutes = Array(stride(from: -120, through: 60, by: 10))
        .filter { $0 != 0 }
    static let defaultOffsetMinutes = -30

    var offsetMinutes: Int
    var isOffsetAlertEnabled: Bool
    var isMainAlertEnabled: Bool

    init(
        offsetMinutes: Int = Self.defaultOffsetMinutes,
        isOffsetAlertEnabled: Bool = false,
        isMainAlertEnabled: Bool = true
    ) {
        self.offsetMinutes = Self.normalizedOffset(offsetMinutes)
        self.isOffsetAlertEnabled = isOffsetAlertEnabled
        self.isMainAlertEnabled = isMainAlertEnabled || !isOffsetAlertEnabled
    }

    var normalized: Self {
        Self(
            offsetMinutes: offsetMinutes,
            isOffsetAlertEnabled: isOffsetAlertEnabled,
            isMainAlertEnabled: isMainAlertEnabled
        )
    }

    var shouldScheduleMainAlert: Bool {
        isMainAlertEnabled
    }

    func offsetFireDate(relativeTo scheduledDate: Date) -> Date {
        scheduledDate.addingTimeInterval(Double(offsetMinutes) * 60)
    }

    func localizedOffsetDescription(bundle: Bundle) -> String {
        let minutes = abs(offsetMinutes)

        let duration: String
        if minutes < 60 {
            duration = String(localized: "\(minutes) minutes", bundle: bundle)
        } else if minutes == 60 {
            duration = String(localized: "1 hour", bundle: bundle)
        } else if minutes % 60 == 0 {
            duration = String(localized: "\(minutes / 60) hours", bundle: bundle)
        } else {
            duration = String(localized: "\(minutes / 60)h \(minutes % 60)m", bundle: bundle)
        }

        if offsetMinutes < 0 {
            return String(localized: "\(duration) before", bundle: bundle)
        }
        return String(localized: "\(duration) after", bundle: bundle)
    }

    func localizedAlertTitle(subject: String, bundle: Bundle) -> String {
        if offsetMinutes < 0 {
            return String(localized: "\(subject) in \(abs(offsetMinutes)) min", bundle: bundle)
        } else if offsetMinutes > 0 {
            return String(localized: "\(abs(offsetMinutes)) min after \(subject)", bundle: bundle)
        }
        return subject
    }

    private static func normalizedOffset(_ offset: Int) -> Int {
        let clamped = min(max(offset, -120), 60)
        let rounded = Int((Double(clamped) / 10).rounded()) * 10
        if rounded == 0 {
            if offset > 0 { return 10 }
            if offset < 0 { return -10 }
            return defaultOffsetMinutes
        }
        return rounded
    }
}

enum AlertScheduleSelection: CaseIterable, Hashable {
    case mainOnly
    case offsetOnly
    case both

    init(settings: AlertTimingSettings) {
        if settings.isOffsetAlertEnabled && settings.isMainAlertEnabled {
            self = .both
        } else if settings.isOffsetAlertEnabled {
            self = .offsetOnly
        } else {
            self = .mainOnly
        }
    }

    func applying(to settings: AlertTimingSettings) -> AlertTimingSettings {
        var updated = settings
        switch self {
        case .mainOnly:
            updated.isMainAlertEnabled = true
            updated.isOffsetAlertEnabled = false
        case .offsetOnly:
            updated.isMainAlertEnabled = false
            updated.isOffsetAlertEnabled = true
        case .both:
            updated.isMainAlertEnabled = true
            updated.isOffsetAlertEnabled = true
        }
        return updated.normalized
    }
}

@Model
final class UserPreferences {
    /// Versioned Auto/preset/Custom payload. The legacy raw value remains for
    /// lightweight SwiftData compatibility but is no longer a source of truth.
    var calculationSettingsData: Data?
    var calculationMethodRawValue: String = CalculationMethodInfo.MuslimWorldLeague.rawValue
    var asrJuristicMethodRawValue: String = AsrJuristicMethod.hanafi.rawValue
    var highLatitudeRuleRawValue: String = HighLatitudeRuleOption.middleOfTheNight.rawValue

    // Per-prayer notification mode: silent / notification / alarm
    var tahajjudNotificationMode: String = PrayerNotificationMode.silent.rawValue
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

    // Legacy pre-alarm storage. New signed offset/main-time settings are encoded below.
    var tahajjudPreAlarmMinutes: Int = 0
    var fajrPreAlarmMinutes: Int = 0
    var dhuhrPreAlarmMinutes: Int = 0
    var asrPreAlarmMinutes: Int = 0
    var maghribPreAlarmMinutes: Int = 0
    var ishaPreAlarmMinutes: Int = 0
    var alertTimingSettingsData: Data?

    // Ramadan
    var ramadanAutoDetect: Bool = true
    var ramadanManualOverride: Bool = false
    var suhoorBufferMinutes: Int = 10
    var useArabicNumerals: Bool = false

    init() {}

    func alertTimingSettings(for prayer: PrayerName) -> AlertTimingSettings {
        if let settings = decodedAlertTimingSettings()[prayer.rawValue] {
            return settings.normalized
        }

        let legacyMinutesBefore = legacyPreAlarmMinutes(for: prayer)
        return AlertTimingSettings(
            offsetMinutes: legacyMinutesBefore == 0
                ? AlertTimingSettings.defaultOffsetMinutes
                : -legacyMinutesBefore,
            isOffsetAlertEnabled: legacyMinutesBefore != 0,
            isMainAlertEnabled: true
        )
    }

    func setAlertTimingSettings(_ settings: AlertTimingSettings, for prayer: PrayerName) {
        var allSettings = decodedAlertTimingSettings()
        allSettings[prayer.rawValue] = settings.normalized
        alertTimingSettingsData = try? JSONEncoder().encode(allSettings)
        setLegacyPreAlarmMinutes(0, for: prayer)
    }

    private func decodedAlertTimingSettings() -> [String: AlertTimingSettings] {
        guard let alertTimingSettingsData,
              let settings = try? JSONDecoder().decode(
                [String: AlertTimingSettings].self,
                from: alertTimingSettingsData
              ) else {
            return [:]
        }
        return settings
    }

    private func legacyPreAlarmMinutes(for prayer: PrayerName) -> Int {
        switch prayer {
        case .tahajjud: return tahajjudPreAlarmMinutes
        case .fajr: return fajrPreAlarmMinutes
        case .dhuhr: return dhuhrPreAlarmMinutes
        case .asr: return asrPreAlarmMinutes
        case .maghrib: return maghribPreAlarmMinutes
        case .isha: return ishaPreAlarmMinutes
        }
    }

    private func setLegacyPreAlarmMinutes(_ value: Int, for prayer: PrayerName) {
        switch prayer {
        case .tahajjud: tahajjudPreAlarmMinutes = value
        case .fajr: fajrPreAlarmMinutes = value
        case .dhuhr: dhuhrPreAlarmMinutes = value
        case .asr: asrPreAlarmMinutes = value
        case .maghrib: maghribPreAlarmMinutes = value
        case .isha: ishaPreAlarmMinutes = value
        }
    }
}
