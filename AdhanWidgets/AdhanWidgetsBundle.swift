import WidgetKit
import SwiftUI
@preconcurrency import Adhan

@main
struct AdhanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
    }
}

// MARK: - Widget Language Helper

enum WidgetLanguage {
    private static let appGroupId = "group.shariq.adhanapp.com"

    static var currentLanguage: String {
        UserDefaults(suiteName: appGroupId)?.string(forKey: "appLanguage") ?? "en"
    }

    static func localized(_ key: String) -> String {
        let lang = currentLanguage
        // English is the source language — keys are already English, no lookup needed
        if lang == "en" { return key }
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let lprojBundle = Bundle(path: path) {
            return lprojBundle.localizedString(forKey: key, value: key, table: nil)
        }
        return key
    }
}

// MARK: - Widget

struct PrayerTimesWidget: Widget {
    let kind: String = "PrayerTimesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Prayer Times")
        .description("View upcoming prayer times at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Timeline Entry

struct PrayerWidgetEntry: TimelineEntry {
    let date: Date
    /// Upcoming prayers (crosses day boundary) — used by small/medium/rectangular/inline/circular
    let upcoming: [(name: String, time: Date, isNext: Bool)]
    /// Full day of prayers (6 entries, current or next day) — used by large widget
    let allPrayers: [(name: String, time: Date, isNext: Bool)]
    let cityName: String
}

// MARK: - Timeline Provider

struct PrayerTimelineProvider: TimelineProvider {
    private let appGroupId = "group.shariq.adhanapp.com"

    func placeholder(in context: Context) -> PrayerWidgetEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        completion(createEntry() ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        let baseEntry = createEntry() ?? sampleEntry()
        let now = Date()

        var entries: [PrayerWidgetEntry] = [baseEntry]

        // Create a transition entry at each upcoming prayer time so the widget refreshes.
        // Each transition removes the just-passed prayer so .prefix(3) stays correct.
        for (idx, prayer) in baseEntry.upcoming.enumerated() where prayer.time > now {
            let remaining = Array(baseEntry.upcoming.suffix(from: idx + 1))
            var updatedUpcoming = remaining.map { ($0.name, $0.time, false) }
            if !updatedUpcoming.isEmpty {
                updatedUpcoming[0].2 = true
            }
            entries.append(PrayerWidgetEntry(
                date: prayer.time,
                upcoming: updatedUpcoming,
                allPrayers: baseEntry.allPrayers,
                cityName: baseEntry.cityName
            ))
        }

        // Refresh after the last upcoming prayer, or in 1 minute if none
        let lastUpcomingTime = baseEntry.upcoming.last(where: { $0.time > now })?.time
        let refreshDate = lastUpcomingTime?.addingTimeInterval(60) ?? now.addingTimeInterval(60)
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    private func createEntry() -> PrayerWidgetEntry? {
        // Always use calculateFreshEntry which computes today + tomorrow
        return calculateFreshEntry()
    }

    private func calculateFreshEntry() -> PrayerWidgetEntry? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return nil }
        let lat = defaults.double(forKey: "lastLocationLatitude")
        let lon = defaults.double(forKey: "lastLocationLongitude")
        guard lat != 0 || lon != 0 else { return nil }

        let cityName = defaults.string(forKey: "lastCityName") ?? "Unknown"
        let now = Date()
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day], from: now)
        let dateComponents = DateComponents(calendar: cal, year: components.year, month: components.month, day: components.day)
        let coordinates = Coordinates(latitude: lat, longitude: lon)
        let savedMethod = defaults.string(forKey: "calculationMethod")
        let calcMethod: CalculationMethod = {
            switch savedMethod {
            case "Muslim World League": return .muslimWorldLeague
            case "Egyptian General Authority": return .egyptian
            case "University of Islamic Sciences, Karachi": return .karachi
            case "Umm Al-Qura University, Makkah": return .ummAlQura
            case "Dubai": return .dubai
            case "Moonsighting Committee": return .moonsightingCommittee
            case "ISNA (North America)": return .northAmerica
            case "Kuwait": return .kuwait
            case "Qatar": return .qatar
            case "Singapore": return .singapore
            case "Diyanet İşleri Başkanlığı, Turkey": return .turkey
            default: return .muslimWorldLeague
            }
        }()
        let params = calcMethod.params

        guard let prayerTimes = PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else {
            return nil
        }

        // Calculate Tahajjud: last third of the night
        let tahajjudTime: Date = {
            let cal = Calendar.current
            if let yesterday = cal.date(byAdding: .day, value: -1, to: now) {
                let yComps = cal.dateComponents([.year, .month, .day], from: yesterday)
                let yDateComps = DateComponents(calendar: cal, year: yComps.year, month: yComps.month, day: yComps.day)
                if let yPrayers = PrayerTimes(coordinates: coordinates, date: yDateComps, calculationParameters: params) {
                    let nightDuration = prayerTimes.fajr.timeIntervalSince(yPrayers.isha)
                    return yPrayers.isha.addingTimeInterval(nightDuration * 2.0 / 3.0)
                }
            }
            return prayerTimes.fajr.addingTimeInterval(-2 * 3600)
        }()

        let names = ["Tahajjud", "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let times = [tahajjudTime, prayerTimes.fajr, prayerTimes.dhuhr, prayerTimes.asr, prayerTimes.maghrib, prayerTimes.isha]

        // Build today's full list
        var todayPrayers: [(name: String, time: Date, isNext: Bool)] = []
        var foundNext = false
        for i in 0..<names.count {
            let isNext = !foundNext && times[i] > now
            if isNext { foundNext = true }
            todayPrayers.append((name: names[i], time: times[i], isNext: isNext))
        }

        // Calculate tomorrow's prayers
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let tComps = cal.dateComponents([.year, .month, .day], from: tomorrow)
        let tDateComps = DateComponents(calendar: cal, year: tComps.year, month: tComps.month, day: tComps.day)
        let tPrayerTimes = PrayerTimes(coordinates: coordinates, date: tDateComps, calculationParameters: params)

        var tomorrowPrayers: [(name: String, time: Date, isNext: Bool)] = []
        if let tPrayerTimes {
            let tTahajjud: Date = {
                let nightDuration = tPrayerTimes.fajr.timeIntervalSince(prayerTimes.isha)
                return prayerTimes.isha.addingTimeInterval(nightDuration * 2.0 / 3.0)
            }()
            let tTimes = [tTahajjud, tPrayerTimes.fajr, tPrayerTimes.dhuhr, tPrayerTimes.asr, tPrayerTimes.maghrib, tPrayerTimes.isha]
            var tFoundNext = false
            for i in 0..<names.count {
                let isNext = !foundNext && !tFoundNext && tTimes[i] > now
                if isNext { tFoundNext = true }
                tomorrowPrayers.append((name: names[i], time: tTimes[i], isNext: isNext))
            }
        }

        // Upcoming: today's remaining future prayers + tomorrow's prayers
        let todayUpcoming = todayPrayers.filter { $0.time > now }
        let upcoming = todayUpcoming + tomorrowPrayers

        // For large widget: show today's full 6 if any are upcoming, otherwise tomorrow's full 6
        let allPrayers = foundNext ? todayPrayers : tomorrowPrayers.isEmpty ? todayPrayers : tomorrowPrayers

        return PrayerWidgetEntry(
            date: now,
            upcoming: upcoming,
            allPrayers: allPrayers,
            cityName: cityName
        )
    }

    private func sampleEntry() -> PrayerWidgetEntry {
        let now = Date()
        let cal = Calendar.current
        let all: [(name: String, time: Date, isNext: Bool)] = [
            ("Tahajjud", cal.date(bySettingHour: 3, minute: 30, second: 0, of: now)!, false),
            ("Fajr", cal.date(bySettingHour: 5, minute: 15, second: 0, of: now)!, false),
            ("Dhuhr", cal.date(bySettingHour: 12, minute: 30, second: 0, of: now)!, false),
            ("Asr", cal.date(bySettingHour: 15, minute: 45, second: 0, of: now)!, false),
            ("Maghrib", cal.date(bySettingHour: 18, minute: 42, second: 0, of: now)!, true),
            ("Isha", cal.date(bySettingHour: 20, minute: 15, second: 0, of: now)!, false),
        ]
        let upcoming = all.filter { $0.time > now || $0.isNext }
        return PrayerWidgetEntry(
            date: now,
            upcoming: upcoming.isEmpty ? all : upcoming,
            allPrayers: all,
            cityName: "Mecca"
        )
    }
}

// MARK: - Shared Codable Types (for reading app group data)

struct SharedPrayerEntry: Codable {
    let prayer: String
    let time: Date
    let isNext: Bool

    enum CodingKeys: String, CodingKey {
        case prayer, time, isNext
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The prayer field is nested in the PrayerTimeEntry codable
        // We read the raw value from the PrayerName enum
        prayer = try container.decode(String.self, forKey: .prayer)
        time = try container.decode(Date.self, forKey: .time)
        isNext = (try? container.decode(Bool.self, forKey: .isNext)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prayer, forKey: .prayer)
        try container.encode(time, forKey: .time)
        try container.encode(isNext, forKey: .isNext)
    }
}

struct SharedDailyPrayerTimes: Codable {
    let date: Date
    let entries: [SharedPrayerEntry]
    let cityName: String
    let hijriDate: String
}

// MARK: - Widget Views

struct PrayerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PrayerWidgetEntry

    private func localizedName(_ name: String) -> String {
        WidgetLanguage.localized(name)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale.autoupdatingCurrent
        return formatter.string(from: date)
    }

    private func formattedTimeCompact(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        case .accessoryInline:
            inlineWidget
        case .accessoryCircular:
            circularWidget
        case .accessoryRectangular:
            rectangularWidget
        default:
            smallWidget
        }
    }

    // MARK: - System Small

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let next = entry.upcoming.first(where: { $0.isNext }) ?? entry.upcoming.first {
                Text(localizedName(next.name))
                    .font(.headline)
                Text(next.time, style: .time)
                    .font(.title.bold())
                    .monospacedDigit()
            } else {
                Text(WidgetLanguage.localized("No upcoming"))
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - System Medium

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.cityName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(Array(entry.upcoming.prefix(3).enumerated()), id: \.offset) { _, prayer in
                HStack {
                    Text(localizedName(prayer.name))
                        .font(.subheadline.weight(prayer.isNext ? .bold : .regular))
                    Spacer()
                    Text(prayer.time, style: .time)
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - System Large

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.cityName)
                .font(.headline)

            Divider()

            ForEach(Array(entry.allPrayers.enumerated()), id: \.offset) { _, prayer in
                HStack {
                    Text(localizedName(prayer.name))
                        .font(.body.weight(prayer.isNext ? .bold : .regular))
                    Spacer()
                    Text(prayer.time, style: .time)
                        .font(.body)
                        .monospacedDigit()
                }
                .padding(.vertical, 2)
                .background(prayer.isNext ? Color.accentColor.opacity(0.1) : .clear)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Accessory Inline

    private var inlineWidget: some View {
        Group {
            if let next = entry.upcoming.first(where: { $0.isNext }) ?? entry.upcoming.first {
                Text("\(localizedName(next.name)) \(formattedTime(next.time))")
            } else {
                Text(WidgetLanguage.localized("No upcoming prayer"))
            }
        }
    }

    // MARK: - Accessory Circular

    private var circularWidget: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                if let next = entry.upcoming.first(where: { $0.isNext }) ?? entry.upcoming.first {
                    Image(systemName: iconFor(next.name))
                        .font(.caption2)
                    Text(formattedTimeCompact(next.time))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // MARK: - Accessory Rectangular

    private var rectangularWidget: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(entry.upcoming.prefix(3).enumerated()), id: \.offset) { _, prayer in
                HStack {
                    Text(localizedName(prayer.name))
                        .font(.caption2)
                    Spacer()
                    Text(formattedTime(prayer.time))
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private func iconFor(_ name: String) -> String {
        switch name {
        case "Tahajjud": return "moon.zzz.fill"
        case "Fajr": return "sun.horizon.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "sun.min.fill"
        case "Maghrib": return "sunset.fill"
        case "Isha": return "moon.stars.fill"
        default: return "clock.fill"
        }
    }
}
