import WidgetKit
import SwiftUI
@preconcurrency import Adhan

@main
struct AthanWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
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
    let hijriDate: String
    let isRamadan: Bool
    let ramadanDay: Int?
}

// MARK: - Timeline Provider

struct PrayerTimelineProvider: TimelineProvider {
    private let appGroupId = "group.com.shariqwaseem.athanapp"

    func placeholder(in context: Context) -> PrayerWidgetEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        completion(createEntry() ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        let entry = createEntry() ?? sampleEntry()

        // Schedule next update at the next prayer time
        let nextPrayer = entry.prayers.first(where: { $0.isNext })
        let nextUpdate = nextPrayer?.time ?? Calendar.current.date(byAdding: .hour, value: 1, to: Date())!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
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

        return PrayerWidgetEntry(
            date: now,
            prayers: prayers,
            cityName: daily.cityName,
            hijriDate: daily.hijriDate,
            isRamadan: false,
            ramadanDay: nil
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

        var hijriCal = Calendar(identifier: .islamicUmmAlQura)
        hijriCal.locale = .current
        let formatter = DateFormatter()
        formatter.calendar = hijriCal
        formatter.dateStyle = .long
        let hijri = formatter.string(from: now)

        let hijriComponents = hijriCal.dateComponents([.month, .day], from: now)
        let isRamadan = hijriComponents.month == 9

        return PrayerWidgetEntry(
            date: now,
            prayers: prayers,
            cityName: cityName,
            hijriDate: hijri,
            isRamadan: isRamadan,
            ramadanDay: isRamadan ? hijriComponents.day : nil
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
            cityName: "Mecca",
            hijriDate: "",
            isRamadan: false,
            ramadanDay: nil
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
                Text(next.name)
                    .font(.headline)
                Text(next.time, style: .time)
                    .font(.title2.bold())
                    .monospacedDigit()
                Text(next.time, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No upcoming")
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

            let upcoming = entry.prayers.filter { $0.time > Date() }.prefix(3)
            ForEach(Array(upcoming.enumerated()), id: \.offset) { _, prayer in
                HStack {
                    Text(prayer.name)
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
            HStack {
                VStack(alignment: .leading) {
                    Text(entry.cityName)
                        .font(.headline)
                    Text(entry.hijriDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if entry.isRamadan, let day = entry.ramadanDay {
                    Text("Ramadan Day \(day)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.yellow.opacity(0.2), in: Capsule())
                }
            }

            Divider()

            ForEach(Array(entry.prayers.enumerated()), id: \.offset) { _, prayer in
                HStack {
                    Text(prayer.name)
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
                Text("\(next.name) \(next.time, style: .time)")
            } else {
                Text("No upcoming prayer")
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
            let upcoming = entry.prayers.filter { $0.time > Date() }.prefix(3)
            ForEach(Array(upcoming.enumerated()), id: \.offset) { _, prayer in
                HStack {
                    Text(prayer.name)
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
