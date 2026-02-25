import Foundation

enum PrayerName: String, CaseIterable, Identifiable, Sendable, Codable {
    case tahajjud = "Tahajjud"
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    var id: String { rawValue }

    var localizedName: String {
        String(localized: String.LocalizationValue(rawValue), bundle: LanguageManager.shared.bundle)
    }

    var systemImage: String {
        switch self {
        case .tahajjud: return "moon.zzz.fill"
        case .fajr: return "sun.horizon.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}

struct PrayerTimeEntry: Identifiable, Sendable, Codable {
    let prayer: PrayerName
    let time: Date
    var isNext: Bool = false
    var isCurrent: Bool = false
    var manualAdjustmentMinutes: Int = 0

    var id: String { prayer.rawValue }

    var adjustedTime: Date {
        Calendar.current.date(byAdding: .minute, value: manualAdjustmentMinutes, to: time) ?? time
    }
}

struct DailyPrayerTimes: Sendable, Codable {
    let date: Date
    let entries: [PrayerTimeEntry]
    let cityName: String
    let hijriDate: String
}
