import Foundation

extension CalculationMethodInfo {
    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue), bundle: LanguageManager.shared.bundle)
    }
}

extension AsrJuristicMethod {
    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue), bundle: LanguageManager.shared.bundle)
    }
}

extension HighLatitudeRuleOption {
    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue), bundle: LanguageManager.shared.bundle)
    }
}

enum PrayerNotificationMode: String, CaseIterable, Identifiable, Sendable {
    case silent = "Silent"
    case notification = "Notification"
    case alarm = "Alarm"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .silent: return "bell.slash.fill"
        case .notification: return "bell.fill"
        case .alarm: return "alarm.fill"
        }
    }

    var description: String {
        switch self {
        case .silent: return "No notification"
        case .notification: return "Standard notification with sound"
        case .alarm: return "Full alarm, bypasses Silent and Focus Modes"
        }
    }

    var localizedName: String {
        let bundle = LanguageManager.shared.bundle
        switch self {
        case .silent: return String(localized: "Silent", bundle: bundle)
        case .notification: return String(localized: "Notification", bundle: bundle)
        case .alarm: return String(localized: "Alarm", bundle: bundle)
        }
    }

    var localizedDescription: String {
        String(localized: String.LocalizationValue(description), bundle: LanguageManager.shared.bundle)
    }
}
