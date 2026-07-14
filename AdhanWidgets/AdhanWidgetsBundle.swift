import WidgetKit
import SwiftUI
import AppIntents
@preconcurrency import Adhan

#if canImport(AlarmKit)
import AlarmKit
#endif

@main
struct AdhanWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        PrayerTimesWidget()
        #if canImport(AlarmKit)
//        if #available(iOS 26, *) {
//            AlarmSnoozeActivityWidget()
//        }
        #endif
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
    /// Tomorrow's full day of prayers — used by timeline transitions after today's last prayer
    let tomorrowAllPrayers: [(name: String, time: Date, isNext: Bool)]
    /// How many entries at the start of `upcoming` belong to today (rest are tomorrow)
    let todayUpcomingCount: Int
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
        let cal = Calendar.current

        var entries: [PrayerWidgetEntry] = [baseEntry]

        // Create a transition entry at each upcoming prayer time so the widget refreshes.
        // Each transition removes the just-passed prayer so .prefix(3) stays correct.
        for (idx, prayer) in baseEntry.upcoming.enumerated() where prayer.time > now {
            let remaining = Array(baseEntry.upcoming.suffix(from: idx + 1))
            var updatedUpcoming = remaining.map { ($0.name, $0.time, false) }
            if !updatedUpcoming.isEmpty {
                updatedUpcoming[0].2 = true
            }

            let transitionTime = prayer.time

            // Once all of today's prayers have passed, switch to tomorrow's full day for the large widget
            let pastTodaysPrayers = baseEntry.todayUpcomingCount > 0 && idx >= baseEntry.todayUpcomingCount - 1
            let baseList = pastTodaysPrayers && !baseEntry.tomorrowAllPrayers.isEmpty
                ? baseEntry.tomorrowAllPrayers
                : baseEntry.allPrayers

            var updatedAllPrayers = baseList.map { ($0.name, $0.time, false) }
            if let nextIdx = updatedAllPrayers.firstIndex(where: { $0.1 > transitionTime }) {
                updatedAllPrayers[nextIdx].2 = true
            }

            entries.append(PrayerWidgetEntry(
                date: prayer.time,
                upcoming: updatedUpcoming,
                allPrayers: updatedAllPrayers,
                tomorrowAllPrayers: baseEntry.tomorrowAllPrayers,
                todayUpcomingCount: max(0, baseEntry.todayUpcomingCount - idx - 1),
                cityName: baseEntry.cityName
            ))
        }

        // Refresh at midnight so the widget recalculates for the new day
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
        let timeline = Timeline(entries: entries, policy: .after(midnight))
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
        let countryCode = defaults.string(forKey: "lastCountryCode")
        let now = Date()
        let cal = Calendar.current
        let settings = CalculationSettingsStorage.load(from: defaults) ?? CalculationSettingsPayload()
        let configuration = settings.selection.resolved(countryCode: countryCode)
        let asrMethod = AsrJuristicMethod(rawValue: defaults.string(forKey: "asrMethod") ?? "") ?? .hanafi
        let highLatitudeRule = HighLatitudeRuleOption(rawValue: defaults.string(forKey: "highLatitudeRule") ?? "") ?? .middleOfTheNight
        let calculationCore = PrayerCalculationCore(calendar: cal)

        // Read manual adjustments
        let manualAdjustments: [String: Int] = {
            guard let data = defaults.data(forKey: "manualAdjustments"),
                  let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
                return [:]
            }
            return decoded
        }()

        func adjusted(_ prayers: [BasePrayerTime]) -> [(name: String, time: Date, isNext: Bool)] {
            prayers.map { prayer in
                let adjustment = manualAdjustments[prayer.prayer.rawValue] ?? 0
                let time = cal.date(byAdding: .minute, value: adjustment, to: prayer.time) ?? prayer.time
                return (name: prayer.prayer.rawValue, time: time, isNext: false)
            }
        }

        let todayBase = calculationCore.calculate(
            date: now,
            latitude: lat,
            longitude: lon,
            configuration: configuration,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule
        )
        guard !todayBase.isEmpty else { return nil }
        let todayTimes = adjusted(todayBase)

        // Build today's full list
        var todayPrayers: [(name: String, time: Date, isNext: Bool)] = []
        var foundNext = false
        for prayer in todayTimes {
            let isNext = !foundNext && prayer.time > now
            if isNext { foundNext = true }
            todayPrayers.append((name: prayer.name, time: prayer.time, isNext: isNext))
        }

        // Calculate tomorrow's prayers
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let tomorrowTimes = adjusted(calculationCore.calculate(
            date: tomorrow,
            latitude: lat,
            longitude: lon,
            configuration: configuration,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule
        ))
        var tomorrowPrayers: [(name: String, time: Date, isNext: Bool)] = []
        var tomorrowFoundNext = false
        for prayer in tomorrowTimes {
            let isNext = !foundNext && !tomorrowFoundNext && prayer.time > now
            if isNext { tomorrowFoundNext = true }
            tomorrowPrayers.append((name: prayer.name, time: prayer.time, isNext: isNext))
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
            tomorrowAllPrayers: tomorrowPrayers,
            todayUpcomingCount: todayUpcoming.count,
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
            tomorrowAllPrayers: all,
            todayUpcomingCount: upcoming.isEmpty ? 0 : upcoming.count,
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
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(prayer.isNext ? Color.accentColor.opacity(0.15) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

// MARK: - AlarmKit Live Activity

#if canImport(AlarmKit)
@available(iOS 26, *)
struct AlarmSnoozeActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<AdhanAlarmMetadata>.self) { context in
            lockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    alarmTitle(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: alarmIcon(metadata: context.attributes.metadata))
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    bottomView(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                countdown(state: context.state, maxWidth: 44)
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                AlarmProgressView(
                    metadata: context.attributes.metadata,
                    mode: context.state.mode,
                    tint: context.attributes.tintColor
                )
            } minimal: {
                AlarmProgressView(
                    metadata: context.attributes.metadata,
                    mode: context.state.mode,
                    tint: context.attributes.tintColor
                )
            }
            .keylineTint(context.attributes.tintColor)
        }
    }

    private func lockScreenView(
        attributes: AlarmAttributes<AdhanAlarmMetadata>,
        state: AlarmPresentationState
    ) -> some View {
        VStack {
            HStack(alignment: .top) {
                alarmTitle(attributes: attributes, state: state)
                Spacer()
                Image(systemName: alarmIcon(metadata: attributes.metadata))
                    .foregroundStyle(attributes.tintColor)
            }

            bottomView(attributes: attributes, state: state)
        }
        .padding(12)
    }

    private func bottomView(
        attributes: AlarmAttributes<AdhanAlarmMetadata>,
        state: AlarmPresentationState
    ) -> some View {
        HStack {
            countdown(state: state, maxWidth: 150)
                .font(.system(size: 40, design: .rounded))
            Spacer()
            AlarmControls(presentation: attributes.presentation, state: state)
        }
    }

    @ViewBuilder
    private func countdown(
        state: AlarmPresentationState,
        maxWidth: CGFloat = .infinity
    ) -> some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
            case .paused(let paused):
                let remaining = Duration.seconds(
                    paused.totalCountdownDuration - paused.previouslyElapsedDuration
                )
                let pattern: Duration.TimeFormatStyle.Pattern = remaining > .seconds(60 * 60)
                    ? .hourMinuteSecond
                    : .minuteSecond
                Text(remaining.formatted(.time(pattern: pattern)))
            default:
                EmptyView()
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: maxWidth, alignment: .leading)
    }

    @ViewBuilder
    private func alarmTitle(
        attributes: AlarmAttributes<AdhanAlarmMetadata>,
        state: AlarmPresentationState
    ) -> some View {
        let title: LocalizedStringResource? = switch state.mode {
        case .countdown:
            attributes.presentation.countdown?.title
        case .paused:
            attributes.presentation.paused?.title
        case .alert:
            attributes.presentation.alert.title
        @unknown default:
            nil
        }

        Text(title ?? "")
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
            .padding(.leading, 6)
    }

    private func alarmIcon(metadata: AdhanAlarmMetadata?) -> String {
        guard let prayerName = metadata?.prayerName else { return "alarm.fill" }
        if prayerName.hasSuffix("_prealarm") { return "bell.badge.fill" }
        if prayerName.hasPrefix("custom_") { return "alarm.fill" }
        return "moon.stars.fill"
    }
}

@available(iOS 26, *)
private struct AlarmProgressView: View {
    let metadata: AdhanAlarmMetadata?
    let mode: AlarmPresentationState.Mode
    let tint: Color

    var body: some View {
        Group {
            switch mode {
            case .countdown(let countdown):
                ProgressView(
                    timerInterval: Date.now...countdown.fireDate,
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: {
                        Image(systemName: alarmIcon)
                            .scaleEffect(0.9)
                    }
                )
            case .paused(let paused):
                let remaining = paused.totalCountdownDuration - paused.previouslyElapsedDuration
                ProgressView(
                    value: remaining,
                    total: paused.totalCountdownDuration,
                    label: { EmptyView() },
                    currentValueLabel: {
                        Image(systemName: "pause.fill")
                            .scaleEffect(0.8)
                    }
                )
            case .alert:
                Image(systemName: "alarm.waves.left.and.right.fill")
            @unknown default:
                EmptyView()
            }
        }
        .progressViewStyle(.circular)
        .foregroundStyle(tint)
        .tint(tint)
    }

    private var alarmIcon: String {
        guard let prayerName = metadata?.prayerName else { return "alarm.fill" }
        if prayerName.hasSuffix("_prealarm") { return "bell.badge.fill" }
        if prayerName.hasPrefix("custom_") { return "alarm.fill" }
        return "moon.stars.fill"
    }
}

@available(iOS 26, *)
private struct AlarmControls: View {
    let presentation: AlarmPresentation
    let state: AlarmPresentationState

    var body: some View {
        HStack(spacing: 4) {
            switch state.mode {
            case .countdown:
                // A prayer alarm has no pause/resume workflow. Stopping its snooze
                // cancels only this alarm, rather than every alarm in the schedule.
                AlarmButtonView(
                    config: presentation.alert.stopButton,
                    intent: CancelAlarmSnoozeIntent(alarmID: state.alarmID.uuidString),
                    tint: .red
                )
            case .alert:
                AlarmButtonView(
                    config: presentation.alert.stopButton,
                    intent: StopAdhanAlarmIntent(alarmID: state.alarmID.uuidString),
                    tint: .red
                )
            default:
                EmptyView()
            }
        }
    }
}

@available(iOS 26, *)
private struct AlarmButtonView<Intent>: View where Intent: AppIntent {
    let config: AlarmButton
    let intent: Intent
    let tint: Color

    init?(config: AlarmButton?, intent: Intent, tint: Color) {
        guard let config else { return nil }
        self.config = config
        self.intent = intent
        self.tint = tint
    }

    var body: some View {
        Button(intent: intent) {
            Label(config.text, systemImage: config.systemImageName)
                .lineLimit(1)
        }
        .tint(tint)
        .buttonStyle(.borderedProminent)
        .frame(width: 96, height: 30)
    }
}
#endif
