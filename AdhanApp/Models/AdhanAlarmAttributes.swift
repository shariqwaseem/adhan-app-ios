import Foundation
@preconcurrency import Adhan

// MARK: - Shared prayer calculation configuration

/// Preset calculation methods supported by the app. Custom settings are represented
/// by `CalculationSelection.custom` rather than by an unsafe zero-angle preset.
enum CalculationMethodInfo: String, CaseIterable, Identifiable, Codable, Sendable {
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
    case Jafari = "Shia (Jafari)"
    case Turkey = "Diyanet İşleri Başkanlığı, Turkey"

    var id: String { rawValue }

    var shortDisplayName: String {
        switch self {
        case .MuslimWorldLeague: return "Muslim World League"
        case .Egyptian: return "Egyptian"
        case .Karachi: return "Karachi"
        case .UmmAlQura: return "Umm al-Qura"
        case .Dubai: return "Dubai"
        case .MoonsightingCommittee: return "Moonsighting Committee"
        case .NorthAmerica: return "ISNA"
        case .Kuwait: return "Kuwait"
        case .Qatar: return "Qatar"
        case .Singapore: return "Singapore"
        case .Jafari: return "Jafari"
        case .Turkey: return "Turkey"
        }
    }

    static func recommendedMethod(forCountryCode code: String?) -> CalculationMethodInfo {
        guard let code = code?.uppercased() else { return .MuslimWorldLeague }
        switch code {
        case "US", "CA": return .NorthAmerica
        case "EG": return .Egyptian
        case "PK", "BD", "AF": return .Karachi
        case "SA": return .UmmAlQura
        case "AE": return .Dubai
        case "KW": return .Kuwait
        case "QA": return .Qatar
        case "SG", "MY", "ID": return .Singapore
        case "IR", "IQ", "BH", "LB": return .Jafari
        case "TR": return .Turkey
        case "GB": return .MoonsightingCommittee
        default: return .MuslimWorldLeague
        }
    }
}

enum AsrJuristicMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard = "Standard (Shafi'i, Maliki, Hanbali)"
    case hanafi = "Hanafi"

    var id: String { rawValue }
}

enum HighLatitudeRuleOption: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic = "Automatic (Recommended)"
    case middleOfTheNight = "Middle of the Night"
    case seventhOfTheNight = "Seventh of the Night"
    case twilightAngle = "Twilight Angle"

    var id: String { rawValue }
}

/// The definition of evening twilight used by the Moon Sighting Committee
/// calculation method. Raw values are stable persistence identifiers rather
/// than user-facing labels.
enum MoonSightingIshaTwilight: String, CaseIterable, Identifiable, Codable, Sendable {
    case general
    case ahmer
    case abyad

    var id: String { rawValue }
}

enum PrayerName: String, CaseIterable, Identifiable, Codable, Sendable {
    case tahajjud = "Tahajjud"
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    var id: String { rawValue }
}

enum IshaCalculationRule: Codable, Hashable, Sendable {
    case angle(Double)
    case fixedMinutesAfterMaghrib(Int)
}

struct CustomCalculationParameters: Codable, Hashable, Sendable {
    var fajrAngle: Double
    var ishaRule: IshaCalculationRule

    init(fajrAngle: Double, ishaRule: IshaCalculationRule) {
        self.fajrAngle = Self.clampedAngle(fajrAngle)
        switch ishaRule {
        case .angle(let angle):
            self.ishaRule = .angle(Self.clampedAngle(angle))
        case .fixedMinutesAfterMaghrib(let minutes):
            self.ishaRule = .fixedMinutesAfterMaghrib(Self.clampedInterval(minutes))
        }
    }

    static func clampedAngle(_ value: Double) -> Double {
        min(max(value, 1), 30)
    }

    static func clampedInterval(_ value: Int) -> Int {
        min(max(value, 1), 240)
    }

    var validated: CustomCalculationParameters {
        CustomCalculationParameters(fajrAngle: fajrAngle, ishaRule: ishaRule)
    }
}

enum CalculationSelection: Codable, Hashable, Sendable {
    case automatic
    case preset(CalculationMethodInfo)
    case custom(CustomCalculationParameters)

    func resolved(countryCode: String?) -> ResolvedCalculationConfiguration {
        switch self {
        case .automatic:
            return .preset(CalculationMethodInfo.recommendedMethod(forCountryCode: countryCode))
        case .preset(let method):
            return .preset(method)
        case .custom(let parameters):
            return .custom(parameters.validated)
        }
    }
}

enum ResolvedCalculationConfiguration: Hashable, Sendable {
    case preset(CalculationMethodInfo)
    case custom(CustomCalculationParameters)

    var presetMethod: CalculationMethodInfo? {
        guard case .preset(let method) = self else { return nil }
        return method
    }

    var isOfficialUmmAlQura: Bool { presetMethod == .UmmAlQura }

    var logName: String {
        switch self {
        case .preset(let method): return method.rawValue
        case .custom: return "Custom"
        }
    }
}

struct CalculationSettingsPayload: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var selection: CalculationSelection
    var savedCustomParameters: CustomCalculationParameters?
    var updatedAt: Date
    var wasExplicitlySelected: Bool
    var moonSightingIshaTwilight: MoonSightingIshaTwilight

    init(
        selection: CalculationSelection = .automatic,
        savedCustomParameters: CustomCalculationParameters? = nil,
        updatedAt: Date = Date(),
        wasExplicitlySelected: Bool = false,
        moonSightingIshaTwilight: MoonSightingIshaTwilight = .general
    ) {
        self.version = Self.currentVersion
        self.selection = selection
        self.savedCustomParameters = savedCustomParameters
        self.updatedAt = updatedAt
        self.wasExplicitlySelected = wasExplicitlySelected
        self.moonSightingIshaTwilight = moonSightingIshaTwilight
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case selection
        case savedCustomParameters
        case updatedAt
        case wasExplicitlySelected
        case moonSightingIshaTwilight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        selection = try container.decode(CalculationSelection.self, forKey: .selection)
        savedCustomParameters = try container.decodeIfPresent(
            CustomCalculationParameters.self,
            forKey: .savedCustomParameters
        )
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        wasExplicitlySelected = try container.decode(Bool.self, forKey: .wasExplicitlySelected)
        moonSightingIshaTwilight = try container.decodeIfPresent(
            MoonSightingIshaTwilight.self,
            forKey: .moonSightingIshaTwilight
        ) ?? .general
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(selection, forKey: .selection)
        try container.encodeIfPresent(savedCustomParameters, forKey: .savedCustomParameters)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(wasExplicitlySelected, forKey: .wasExplicitlySelected)
        try container.encode(moonSightingIshaTwilight, forKey: .moonSightingIshaTwilight)
    }
}

enum CalculationSettingsStorage {
    static let defaultsKey = "calculationSettings.v1"
    static let iCloudKey = "sync_calculationSettings.v1"

    static func encode(_ payload: CalculationSettingsPayload) -> Data? {
        try? JSONEncoder().encode(payload)
    }

    static func decode(_ data: Data?) -> CalculationSettingsPayload? {
        guard let data,
              var payload = try? JSONDecoder().decode(CalculationSettingsPayload.self, from: data),
              payload.version == CalculationSettingsPayload.currentVersion else {
            return nil
        }
        if case .custom(let custom) = payload.selection {
            payload.selection = .custom(custom.validated)
        }
        payload.savedCustomParameters = payload.savedCustomParameters?.validated
        return payload
    }

    static func load(from defaults: UserDefaults) -> CalculationSettingsPayload? {
        decode(defaults.data(forKey: defaultsKey))
    }

    static func save(_ payload: CalculationSettingsPayload, to defaults: UserDefaults) {
        guard let data = encode(payload) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    /// Prefer an explicit user choice over a migration default, then the newest payload.
    static func preferred(_ payloads: [CalculationSettingsPayload?]) -> CalculationSettingsPayload? {
        let valid = payloads.compactMap { $0 }
        let explicit = valid.filter(\.wasExplicitlySelected)
        return (explicit.isEmpty ? valid : explicit).max(by: { $0.updatedAt < $1.updatedAt })
    }
}

struct BasePrayerTime: Hashable, Sendable {
    let prayer: PrayerName
    let time: Date
}

/// Pure, deterministic calculator shared by the app and widget targets.
struct PrayerCalculationCore: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func calculate(
        date: Date,
        latitude: Double,
        longitude: Double,
        configuration: ResolvedCalculationConfiguration,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        moonSightingIshaTwilight: MoonSightingIshaTwilight = .general
    ) -> [BasePrayerTime] {
        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        let dateComponents = dayComponents(for: date)
        let parameters = calculationParameters(
            for: configuration,
            date: date,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule,
            moonSightingIshaTwilight: moonSightingIshaTwilight
        )

        guard let prayerTimes = PrayerTimes(
            coordinates: coordinates,
            date: dateComponents,
            calculationParameters: parameters
        ) else {
            return []
        }

        var result: [BasePrayerTime] = []
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: date) {
            let yesterdayParameters = calculationParameters(
                for: configuration,
                date: yesterday,
                asrMethod: asrMethod,
                highLatitudeRule: highLatitudeRule,
                moonSightingIshaTwilight: moonSightingIshaTwilight
            )
            if let yesterdayPrayers = PrayerTimes(
                coordinates: coordinates,
                date: dayComponents(for: yesterday),
                calculationParameters: yesterdayParameters
            ) {
                let nightDuration = prayerTimes.fajr.timeIntervalSince(yesterdayPrayers.maghrib)
                if nightDuration > 0 {
                    let tahajjud = yesterdayPrayers.maghrib.addingTimeInterval(nightDuration * 2 / 3)
                    result.append(BasePrayerTime(prayer: .tahajjud, time: tahajjud))
                }
            }
        }

        result.append(contentsOf: [
            BasePrayerTime(prayer: .fajr, time: prayerTimes.fajr),
            BasePrayerTime(prayer: .dhuhr, time: prayerTimes.dhuhr),
            BasePrayerTime(prayer: .asr, time: prayerTimes.asr),
            BasePrayerTime(prayer: .maghrib, time: prayerTimes.maghrib),
            BasePrayerTime(prayer: .isha, time: prayerTimes.isha),
        ])
        return result
    }

    func customParameters(seedFrom method: CalculationMethodInfo) -> CustomCalculationParameters {
        let parameters = presetParameters(for: method)
        if parameters.ishaInterval > 0 {
            return CustomCalculationParameters(
                fajrAngle: parameters.fajrAngle,
                ishaRule: .fixedMinutesAfterMaghrib(parameters.ishaInterval)
            )
        }
        return CustomCalculationParameters(
            fajrAngle: parameters.fajrAngle,
            ishaRule: .angle(parameters.ishaAngle)
        )
    }

    private func dayComponents(for date: Date) -> DateComponents {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        // adhan-swift interprets these civil components with its own Gregorian UTC
        // calendar. Attaching the device calendar/time zone shifts the result twice.
        return DateComponents(year: components.year, month: components.month, day: components.day)
    }

    private func calculationParameters(
        for configuration: ResolvedCalculationConfiguration,
        date: Date,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        moonSightingIshaTwilight: MoonSightingIshaTwilight
    ) -> CalculationParameters {
        var parameters: CalculationParameters
        switch configuration {
        case .preset(let method):
            parameters = presetParameters(for: method)
            if method == .UmmAlQura {
                parameters.ishaInterval = isRamadan(date) ? 120 : 90
            }
        case .custom(let custom):
            let custom = custom.validated
            parameters = CalculationMethod.other.params
            parameters.fajrAngle = custom.fajrAngle
            switch custom.ishaRule {
            case .angle(let angle):
                parameters.ishaAngle = angle
                parameters.ishaInterval = 0
            case .fixedMinutesAfterMaghrib(let minutes):
                parameters.ishaAngle = 0
                parameters.ishaInterval = minutes
            }
        }
        parameters.madhab = asrMethod == .hanafi ? .hanafi : .shafi
        switch highLatitudeRule {
        case .automatic: parameters.highLatitudeRule = nil
        case .middleOfTheNight: parameters.highLatitudeRule = .middleOfTheNight
        case .seventhOfTheNight: parameters.highLatitudeRule = .seventhOfTheNight
        case .twilightAngle: parameters.highLatitudeRule = .twilightAngle
        }
        if configuration.presetMethod == .MoonsightingCommittee {
            switch moonSightingIshaTwilight {
            case .general: parameters.shafaq = .general
            case .ahmer: parameters.shafaq = .ahmer
            case .abyad: parameters.shafaq = .abyad
            }
        }
        return parameters
    }

    private func presetParameters(for method: CalculationMethodInfo) -> CalculationParameters {
        switch method {
        case .MuslimWorldLeague: return CalculationMethod.muslimWorldLeague.params
        case .Egyptian: return CalculationMethod.egyptian.params
        case .Karachi: return CalculationMethod.karachi.params
        case .UmmAlQura: return CalculationMethod.ummAlQura.params
        case .Dubai: return CalculationMethod.dubai.params
        case .MoonsightingCommittee: return CalculationMethod.moonsightingCommittee.params
        case .NorthAmerica: return CalculationMethod.northAmerica.params
        case .Kuwait: return CalculationMethod.kuwait.params
        case .Qatar: return CalculationMethod.qatar.params
        case .Singapore: return CalculationMethod.singapore.params
        case .Jafari: return CalculationMethod.tehran.params
        case .Turkey: return CalculationMethod.turkey.params
        }
    }

    private func isRamadan(_ date: Date) -> Bool {
        var hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        hijriCalendar.timeZone = calendar.timeZone
        return hijriCalendar.component(.month, from: date) == 9
    }
}

#if canImport(AlarmKit)
import AlarmKit
import ActivityKit

@available(iOS 26, *)
struct AdhanAlarmMetadata: AlarmMetadata {
    var prayerName: String
    var prayerTime: Date
}

@available(iOS 26, *)
enum AlarmLiveActivityCleanup {
    static func endActivitiesWithoutCurrentAlarm() async {
        let alarms: [AlarmKit.Alarm]
        do {
            alarms = try AlarmKit.AlarmManager.shared.alarms
        } catch {
            return
        }

        await endActivities(notMatching: activeActivityAlarmIDs(from: alarms))
    }

    static func endActivitiesWithoutCurrentAlarm(in alarms: [AlarmKit.Alarm]) async {
        await endActivities(notMatching: activeActivityAlarmIDs(from: alarms))
    }

    static func endActivities(for alarmIDs: some Sequence<AlarmKit.Alarm.ID>) async {
        let alarmIDs = Set(alarmIDs)
        guard !alarmIDs.isEmpty else { return }

        for activity in Activity<AlarmAttributes<AdhanAlarmMetadata>>.activities
        where alarmIDs.contains(activity.content.state.alarmID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func endAllActivities() async {
        for activity in Activity<AlarmAttributes<AdhanAlarmMetadata>>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func endActivities(notMatching activeAlarmIDs: Set<AlarmKit.Alarm.ID>) async {
        for activity in Activity<AlarmAttributes<AdhanAlarmMetadata>>.activities {
            switch activity.activityState {
            case .ended, .dismissed:
                continue
            default:
                break
            }

            if !activeAlarmIDs.contains(activity.content.state.alarmID) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func activeActivityAlarmIDs(from alarms: [AlarmKit.Alarm]) -> Set<AlarmKit.Alarm.ID> {
        Set(alarms.compactMap { alarm in
            switch alarm.state {
            case .alerting, .countdown:
                return alarm.id
            case .scheduled, .paused:
                return nil
            @unknown default:
                return nil
            }
        })
    }
}
#endif
