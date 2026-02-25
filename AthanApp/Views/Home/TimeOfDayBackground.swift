import SwiftUI

struct TimeOfDayBackground: View {
    let prayerEntries: [PrayerTimeEntry]

    var body: some View {
        let phase = TimePhase.current(for: prayerEntries, at: Date())
        LinearGradient(
            colors: phase.colors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

enum TimePhase: String {
    case preFajr
    case dawn
    case morning
    case midday
    case goldenHour
    case sunset
    case night

    var name: String { rawValue }

    var colors: [Color] {
        switch self {
        case .preFajr:
            return [Color(red: 0.05, green: 0.11, blue: 0.29), Color(red: 0.10, green: 0.16, blue: 0.50)]
        case .dawn:
            return [Color(red: 0.42, green: 0.25, blue: 0.63), Color(red: 0.91, green: 0.39, blue: 0.48)]
        case .morning:
            return [Color(red: 0.34, green: 0.80, blue: 0.95), Color(red: 0.66, green: 0.90, blue: 0.81)]
        case .midday:
            return [Color(red: 0.13, green: 0.59, blue: 0.95), Color(red: 0.39, green: 0.71, blue: 0.96)]
        case .goldenHour:
            return [Color(red: 0.97, green: 0.59, blue: 0.12), Color(red: 1.00, green: 0.82, blue: 0.00)]
        case .sunset:
            return [Color(red: 0.89, green: 0.30, blue: 0.15), Color(red: 0.36, green: 0.15, blue: 0.55)]
        case .night:
            return [Color(red: 0.06, green: 0.05, blue: 0.16), Color(red: 0.04, green: 0.04, blue: 0.10)]
        }
    }

    var textColor: Color {
        switch self {
        case .preFajr, .night, .sunset, .dawn:
            return .white
        case .morning, .midday, .goldenHour:
            return .primary
        }
    }

    static func current(for prayerEntries: [PrayerTimeEntry], at date: Date) -> TimePhase {
        guard !prayerEntries.isEmpty else { return .night }

        let fajr = prayerEntries.first(where: { $0.prayer == .fajr })?.adjustedTime
        let dhuhr = prayerEntries.first(where: { $0.prayer == .dhuhr })?.adjustedTime
        let asr = prayerEntries.first(where: { $0.prayer == .asr })?.adjustedTime
        let maghrib = prayerEntries.first(where: { $0.prayer == .maghrib })?.adjustedTime
        let isha = prayerEntries.first(where: { $0.prayer == .isha })?.adjustedTime

        // Estimate sunrise as midpoint between fajr and dhuhr
        let estimatedSunrise: Date? = {
            guard let f = fajr, let d = dhuhr else { return nil }
            return f.addingTimeInterval((d.timeIntervalSince(f)) * 0.3)
        }()

        if let fajr, date < fajr {
            return .preFajr
        } else if let estimatedSunrise, date < estimatedSunrise {
            return .dawn
        } else if let dhuhr, date < dhuhr {
            return .morning
        } else if let asr, date < asr {
            return .midday
        } else if let maghrib, date < maghrib {
            return .goldenHour
        } else if let isha, date < isha {
            return .sunset
        } else {
            return .night
        }
    }
}
