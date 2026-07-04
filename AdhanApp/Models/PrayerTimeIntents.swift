import AppIntents
import Foundation

enum PrayerIntentName: String, AppEnum, CaseIterable, Sendable {
    case tahajjud
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Prayer")

    static let caseDisplayRepresentations: [PrayerIntentName: DisplayRepresentation] = [
        .tahajjud: "Tahajjud",
        .fajr: "Fajr",
        .dhuhr: "Dhuhr",
        .asr: "Asr",
        .maghrib: "Maghrib",
        .isha: "Isha"
    ]

    var prayerName: PrayerName {
        switch self {
        case .tahajjud: return .tahajjud
        case .fajr: return .fajr
        case .dhuhr: return .dhuhr
        case .asr: return .asr
        case .maghrib: return .maghrib
        case .isha: return .isha
        }
    }
}

struct SiriPrayerTimeService: Sendable {
    private let entriesProvider: @Sendable (Date) -> [PrayerTimeEntry]?

    init(entriesProvider: @escaping @Sendable (Date) -> [PrayerTimeEntry]? = SiriPrayerTimeService.loadEntries) {
        self.entriesProvider = entriesProvider
    }

    func nextPrayerAnswer(now: Date = Date()) -> String {
        guard let next = nextPrayer(after: now) else {
            return "Open Adhan and set your location first, then I can answer prayer time questions."
        }

        let day = dayText(for: next.adjustedTime, relativeTo: now)
        let remaining = remainingTimeText(from: now, to: next.adjustedTime)

        if let remaining {
            return "The next prayer is \(next.prayer.rawValue) at \(timeText(for: next.adjustedTime)) \(day), in \(remaining)."
        }

        return "The next prayer is \(next.prayer.rawValue) now."
    }

    func prayerTimeAnswer(for prayer: PrayerName, now: Date = Date()) -> String {
        guard let entries = entriesProvider(now),
              let entry = entries.first(where: { $0.prayer == prayer }) else {
            return "Open Adhan and set your location first, then I can answer prayer time questions."
        }

        let tense = entry.adjustedTime < now ? "was" : "is"
        return "\(prayer.rawValue) \(tense) at \(timeText(for: entry.adjustedTime)) today."
    }

    private func nextPrayer(after now: Date) -> PrayerTimeEntry? {
        if let today = entriesProvider(now)?
            .sorted(by: { $0.adjustedTime < $1.adjustedTime })
            .first(where: { $0.adjustedTime >= now }) {
            return today
        }

        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) else {
            return nil
        }

        return entriesProvider(tomorrow)?
            .sorted(by: { $0.adjustedTime < $1.adjustedTime })
            .first
    }

    private func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func dayText(for date: Date, relativeTo now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return "today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "tomorrow"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "on \(formatter.string(from: date))"
    }

    private func remainingTimeText(from now: Date, to date: Date) -> String? {
        let interval = date.timeIntervalSince(now)
        guard interval >= 60 else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .full
        return formatter.string(from: interval)
    }

    private static func loadEntries(for date: Date) -> [PrayerTimeEntry]? {
        if let cached = SharedDataManager.loadPrayerTimes(),
           Calendar.current.isDate(cached.date, inSameDayAs: date) {
            return cached.entries
        }

        guard let location = SharedDataManager.loadLocation() else {
            return nil
        }

        return PrayerCalculationService().calculatePrayerTimes(
            date: date,
            latitude: location.latitude,
            longitude: location.longitude,
            method: SharedDataManager.loadCalculationMethod() ?? .MuslimWorldLeague,
            asrMethod: SharedDataManager.loadAsrMethod() ?? .hanafi,
            highLatitudeRule: SharedDataManager.loadHighLatitudeRule() ?? .middleOfTheNight,
            adjustments: SharedDataManager.loadManualAdjustments()
        )
    }
}

struct NextPrayerTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Next Prayer Time"
    static let description = IntentDescription("Ask Adhan for the next prayer time.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriPrayerTimeService().nextPrayerAnswer()))
    }
}

struct SpecificPrayerTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Prayer Time"
    static let description = IntentDescription("Ask Adhan for a specific prayer time.")

    @Parameter(title: "Prayer")
    var prayer: PrayerIntentName

    init() {
        self.prayer = .fajr
    }

    init(prayer: PrayerIntentName) {
        self.prayer = prayer
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: SiriPrayerTimeService().prayerTimeAnswer(for: prayer.prayerName)))
    }
}

struct PrayerTimeShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextPrayerTimeIntent(),
            phrases: [
                "What time is the next prayer in \(.applicationName)",
                "When is the next prayer in \(.applicationName)",
                "Ask \(.applicationName) for the next prayer"
            ],
            shortTitle: "Next Prayer",
            systemImageName: "clock"
        )

        AppShortcut(
            intent: SpecificPrayerTimeIntent(),
            phrases: [
                "What time is \(\.$prayer) in \(.applicationName)",
                "When is \(\.$prayer) in \(.applicationName)",
                "Ask \(.applicationName) for \(\.$prayer)"
            ],
            shortTitle: "Prayer Time",
            systemImageName: "clock.badge"
        )
    }
}
