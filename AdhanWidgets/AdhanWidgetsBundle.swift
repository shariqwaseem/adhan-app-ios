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
    let prayers: [(name: String, time: Date, isNext: Bool)]
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

        // Create one entry per prayer transition so WidgetKit can swap them automatically
        var entries: [PrayerWidgetEntry] = []

        // Entry for right now
        entries.append(baseEntry)

        // Create an entry at each future prayer time, shifting isNext forward
        let futurePrayers = baseEntry.prayers.enumerated().filter { $0.element.time > now }
        for (idx, _) in futurePrayers {
            let transitionDate = baseEntry.prayers[idx].time
            var updatedPrayers: [(name: String, time: Date, isNext: Bool)] = []
            for (j, prayer) in baseEntry.prayers.enumerated() {
                let isNext = (j == idx + 1) && (idx + 1 < baseEntry.prayers.count)
                updatedPrayers.append((name: prayer.name, time: prayer.time, isNext: isNext))
            }
            entries.append(PrayerWidgetEntry(
                date: transitionDate,
                prayers: updatedPrayers,
                cityName: baseEntry.cityName
            ))
        }

        // If no future prayers today, refresh soon to pick up tomorrow's data.
        // Otherwise refresh at midnight.
        let refreshDate: Date
        if futurePrayers.isEmpty {
            // All prayers past — refresh in 1 minute to show tomorrow's prayers
            refreshDate = now.addingTimeInterval(60)
        } else if let lastPrayer = futurePrayers.last {
            // Refresh right after the last prayer of the day
            refreshDate = baseEntry.prayers[lastPrayer.offset].time.addingTimeInterval(60)
        } else {
            let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now)!)
            refreshDate = tomorrow
        }
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    private func createEntry() -> PrayerWidgetEntry? {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = defaults.data(forKey: "cachedPrayerTimes"),
              let daily = try? JSONDecoder().decode(SharedDailyPrayerTimes.self, from: data) else {
            return calculateFreshEntry()
        }

        let now = Date()
        let prayers = daily.entries.map { entry in
            (name: entry.prayer, time: entry.time, isNext: entry.isNext)
        }

        // If all cached prayers are past (after Isha), recalculate to get tomorrow's
        let hasUpcoming = prayers.contains { $0.time > now }
        if !hasUpcoming {
            return calculateFreshEntry()
        }

        return PrayerWidgetEntry(
            date: now,
            prayers: prayers,
            cityName: daily.cityName
        )
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

        var prayers: [(name: String, time: Date, isNext: Bool)] = []
        var foundNext = false
        for i in 0..<names.count {
            let isNext = !foundNext && times[i] > now
            if isNext { foundNext = true }
            prayers.append((name: names[i], time: times[i], isNext: isNext))
        }

        // If all today's prayers are past (after Isha), calculate tomorrow's prayers
        if !foundNext {
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now) else {
                return PrayerWidgetEntry(date: now, prayers: prayers, cityName: cityName)
            }
            let tComps = cal.dateComponents([.year, .month, .day], from: tomorrow)
            let tDateComps = DateComponents(calendar: cal, year: tComps.year, month: tComps.month, day: tComps.day)
            guard let tPrayerTimes = PrayerTimes(coordinates: coordinates, date: tDateComps, calculationParameters: params) else {
                return PrayerWidgetEntry(date: now, prayers: prayers, cityName: cityName)
            }

            let tTahajjud: Date = {
                let nightDuration = tPrayerTimes.fajr.timeIntervalSince(prayerTimes.isha)
                return prayerTimes.isha.addingTimeInterval(nightDuration * 2.0 / 3.0)
            }()

            let tTimes = [tTahajjud, tPrayerTimes.fajr, tPrayerTimes.dhuhr, tPrayerTimes.asr, tPrayerTimes.maghrib, tPrayerTimes.isha]
            prayers = []
            var tFoundNext = false
            for i in 0..<names.count {
                let isNext = !tFoundNext && tTimes[i] > now
                if isNext { tFoundNext = true }
                prayers.append((name: names[i], time: tTimes[i], isNext: isNext))
            }
        }

        return PrayerWidgetEntry(
            date: now,
            prayers: prayers,
            cityName: cityName
        )
    }

    private func sampleEntry() -> PrayerWidgetEntry {
        let now = Date()
        let cal = Calendar.current
        return PrayerWidgetEntry(
            date: now,
            prayers: [
                ("Tahajjud", cal.date(bySettingHour: 3, minute: 30, second: 0, of: now)!, false),
                ("Fajr", cal.date(bySettingHour: 5, minute: 15, second: 0, of: now)!, false),
                ("Dhuhr", cal.date(bySettingHour: 12, minute: 30, second: 0, of: now)!, false),
                ("Asr", cal.date(bySettingHour: 15, minute: 45, second: 0, of: now)!, false),
                ("Maghrib", cal.date(bySettingHour: 18, minute: 42, second: 0, of: now)!, true),
                ("Isha", cal.date(bySettingHour: 20, minute: 15, second: 0, of: now)!, false),
            ],
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
            if let next = entry.prayers.first(where: { $0.isNext }) {
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

            let upcoming = entry.prayers.filter { $0.time > entry.date }.prefix(3)
            ForEach(Array(upcoming.enumerated()), id: \.offset) { _, prayer in
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

            ForEach(Array(entry.prayers.enumerated()), id: \.offset) { _, prayer in
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
            if let next = entry.prayers.first(where: { $0.isNext }) {
                Text("\(localizedName(next.name)) \(next.time, style: .time)")
            } else {
                Text(WidgetLanguage.localized("No upcoming prayer"))
            }
        }
    }

    // MARK: - Accessory Circular

    private var circularWidget: some View {
        VStack(spacing: 2) {
            if let next = entry.prayers.first(where: { $0.isNext }) {
                Image(systemName: iconFor(next.name))
                    .font(.caption)
                Text(next.time, style: .time)
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Accessory Rectangular

    private var rectangularWidget: some View {
        VStack(alignment: .leading, spacing: 2) {
            let upcoming = entry.prayers.filter { $0.time > entry.date }.prefix(3)
            ForEach(Array(upcoming.enumerated()), id: \.offset) { _, prayer in
                HStack {
                    Text(localizedName(prayer.name))
                        .font(.caption2)
                    Spacer()
                    Text(prayer.time, style: .time)
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
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
