import SwiftUI

struct TimeOfDayBackground: View {
    let prayerEntries: [PrayerTimeEntry]

    var body: some View {
        let phase = currentPhase(at: Date())
        LinearGradient(
            colors: phase.colors,
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func currentPhase(at date: Date) -> TimePhase {
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
            return [Color(red: 0.05, green: 0.05, blue: 0.2), Color(red: 0.1, green: 0.1, blue: 0.3)]
        case .dawn:
            return [Color(red: 0.3, green: 0.2, blue: 0.35), Color(red: 0.85, green: 0.55, blue: 0.55)]
        case .morning:
            return [Color(red: 0.45, green: 0.65, blue: 0.85), Color(red: 0.7, green: 0.85, blue: 0.95)]
        case .midday:
            return [Color(red: 0.35, green: 0.6, blue: 0.9), Color(red: 0.55, green: 0.75, blue: 0.95)]
        case .goldenHour:
            return [Color(red: 0.95, green: 0.75, blue: 0.4), Color(red: 0.9, green: 0.6, blue: 0.3)]
        case .sunset:
            return [Color(red: 0.85, green: 0.35, blue: 0.3), Color(red: 0.3, green: 0.15, blue: 0.3)]
        case .night:
            return [Color(red: 0.08, green: 0.08, blue: 0.15), Color(red: 0.05, green: 0.05, blue: 0.1)]
        }
    }
}
