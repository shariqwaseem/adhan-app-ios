import Foundation

enum CalculationMethodInfo: String, CaseIterable, Identifiable, Sendable {
    case MuslimWorldLeague = "Muslim World League"
    case Egyptian = "Egyptian General Authority"
    case Karachi = "University of Islamic Sciences, Karachi"
    case UmmAlQura = "Umm Al-Qura University, Makkah"
    case Dubai = "Dubai"
    case MoonsightingCommittee = "Moonsighting Committee"
    case NorthAmerica = "ISNA (North America)"
    case Kuwait = "Kuwait"
    case Qatar = "Qatar"
    case Singapore = "Singapore"
    case Tehran = "Institute of Geophysics, Tehran"
    case Jafari = "Shia (Jafari)"
    case Turkey = "Diyanet İşleri Başkanlığı, Turkey"
    case Other = "Other"

    var id: String { rawValue }

    static func recommendedMethod(forCountryCode code: String?) -> CalculationMethodInfo {
        guard let code = code?.uppercased() else { return .MuslimWorldLeague }
        switch code {
        case "US", "CA":
            return .NorthAmerica
        case "EG":
            return .Egyptian
        case "PK", "BD", "AF":
            return .Karachi
        case "SA":
            return .UmmAlQura
        case "AE":
            return .Dubai
        case "KW":
            return .Kuwait
        case "QA":
            return .Qatar
        case "SG", "MY", "ID":
            return .Singapore
        case "IR":
            return .Tehran
        case "IQ", "BH", "LB":
            return .Jafari
        case "TR":
            return .Turkey
        case "GB":
            return .MoonsightingCommittee
        default:
            return .MuslimWorldLeague
        }
    }
}

enum AsrJuristicMethod: String, CaseIterable, Identifiable, Sendable {
    case standard = "Standard (Shafi'i, Maliki, Hanbali)"
    case hanafi = "Hanafi"

    var id: String { rawValue }
}

enum HighLatitudeRuleOption: String, CaseIterable, Identifiable, Sendable {
    case middleOfTheNight = "Middle of the Night"
    case seventhOfTheNight = "Seventh of the Night"
    case twilightAngle = "Twilight Angle"

    var id: String { rawValue }
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
        case .alarm: return "Full athan alarm, bypasses Silent Mode"
        }
    }
}
