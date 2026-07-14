import Foundation
import Observation

@Observable
@MainActor
final class PrayerTimesViewModel {
    var prayerEntries: [PrayerTimeEntry] = []
    var hijriDate: String = ""
    var cityName: String = ""
    var countryCode: String? = nil
    var nextPrayer: PrayerTimeEntry? = nil
    var currentPrayer: PrayerTimeEntry? = nil
    var timeUntilNext: TimeInterval = 0
    var isLoading: Bool = true

    private let calculationService: PrayerCalculationServiceProtocol
    private let hijriDateService: HijriDateService
    private let calculationCore: PrayerCalculationCore
    private let calendar: Calendar
    private let persistsCalculationSettings: Bool
    private var calculatedDate: Date?

    // Current calculation parameters — persisted as one versioned payload.
    var calculationSettings: CalculationSettingsPayload {
        didSet {
            persistCalculationSettings()
        }
    }

    var calculationSelection: CalculationSelection { calculationSettings.selection }

    var resolvedCalculationConfiguration: ResolvedCalculationConfiguration {
        calculationSelection.resolved(countryCode: countryCode)
    }

    var effectiveCalculationMethod: CalculationMethodInfo? {
        resolvedCalculationConfiguration.presetMethod
    }

    var calculationSelectionLabel: String {
        switch calculationSelection {
        case .automatic:
            let method = CalculationMethodInfo.recommendedMethod(forCountryCode: countryCode)
            return "Auto (\(method.shortDisplayName))"
        case .preset(let method):
            return method.localizedName
        case .custom:
            return String(localized: "Custom", bundle: LanguageManager.shared.bundle)
        }
    }

    var customCalculationParameters: CustomCalculationParameters {
        if case .custom(let parameters) = calculationSelection {
            return parameters
        }
        if let saved = calculationSettings.savedCustomParameters {
            return saved
        }
        let seed = effectiveCalculationMethod ?? CalculationMethodInfo.recommendedMethod(forCountryCode: countryCode)
        return calculationCore.customParameters(seedFrom: seed)
    }

    var calculationSettingsData: Data? {
        CalculationSettingsStorage.encode(calculationSettings)
    }

    var asrMethod: AsrJuristicMethod = .hanafi {
        didSet {
            UserDefaults.standard.set(asrMethod.rawValue, forKey: "asrMethod")
            SharedDataManager.saveAsrMethod(asrMethod.rawValue)
        }
    }
    var highLatitudeRule: HighLatitudeRuleOption = .middleOfTheNight {
        didSet {
            UserDefaults.standard.set(highLatitudeRule.rawValue, forKey: "highLatitudeRule")
            SharedDataManager.saveHighLatitudeRule(highLatitudeRule.rawValue)
        }
    }

    var manualAdjustments: [PrayerName: Int] = [:]

    // Location
    var latitude: Double = 21.4225  // Mecca default
    var longitude: Double = 39.8262

    init(
        calculationService: PrayerCalculationServiceProtocol? = nil,
        hijriDateService: HijriDateService = HijriDateService(),
        calendar: Calendar = .autoupdatingCurrent,
        initialCalculationSettings: CalculationSettingsPayload? = nil,
        persistsCalculationSettings: Bool = true
    ) {
        self.calculationService = calculationService ?? PrayerCalculationService(calendar: calendar)
        self.hijriDateService = hijriDateService
        self.calendar = calendar
        self.calculationCore = PrayerCalculationCore(calendar: calendar)
        self.persistsCalculationSettings = persistsCalculationSettings

        let iCloudData = initialCalculationSettings == nil && persistsCalculationSettings
            ? NSUbiquitousKeyValueStore.default.data(forKey: CalculationSettingsStorage.iCloudKey)
            : nil
        self.calculationSettings = initialCalculationSettings ?? CalculationSettingsStorage.preferred([
            CalculationSettingsStorage.load(from: .standard),
            Constants.sharedDefaults.flatMap(CalculationSettingsStorage.load(from:)),
            CalculationSettingsStorage.decode(iCloudData),
        ]) ?? CalculationSettingsPayload()

        // Restore saved calculation settings
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "asrMethod"),
           let method = AsrJuristicMethod(rawValue: raw) {
            self.asrMethod = method
        }
        SharedDataManager.saveAsrMethod(asrMethod.rawValue)
        if let raw = defaults.string(forKey: "highLatitudeRule"),
           let rule = HighLatitudeRuleOption(rawValue: raw) {
            self.highLatitudeRule = rule
        }
        SharedDataManager.saveHighLatitudeRule(highLatitudeRule.rawValue)

        // Restore last saved location
        if let saved = SharedDataManager.loadLocation() {
            self.latitude = saved.latitude
            self.longitude = saved.longitude
            self.cityName = saved.cityName
            self.countryCode = saved.countryCode
        }

        persistCalculationSettings()
    }

    func setCalculationSelection(_ selection: CalculationSelection) {
        var settings = calculationSettings
        settings.selection = selection
        if case .custom(let parameters) = selection {
            settings.savedCustomParameters = parameters
        }
        settings.updatedAt = Date()
        settings.wasExplicitlySelected = true
        calculationSettings = settings
    }

    func updateCustomCalculationParameters(_ parameters: CustomCalculationParameters) {
        setCalculationSelection(.custom(parameters.validated))
    }

    func resetCustomCalculationParameters() {
        let method = CalculationMethodInfo.recommendedMethod(forCountryCode: countryCode)
        updateCustomCalculationParameters(calculationCore.customParameters(seedFrom: method))
    }

    @discardableResult
    func mergeCalculationSettings(_ incoming: CalculationSettingsPayload) -> Bool {
        guard let preferred = CalculationSettingsStorage.preferred([calculationSettings, incoming]),
              preferred != calculationSettings else { return false }
        calculationSettings = preferred
        calculateToday()
        return true
    }

    func calculateToday(at now: Date = Date()) {
        hijriDate = hijriDateService.hijriDateString(for: now)
        calculatedDate = now

        prayerEntries = calculationService.calculatePrayerTimes(
            date: now,
            latitude: latitude,
            longitude: longitude,
            configuration: resolvedCalculationConfiguration,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule,
            adjustments: manualAdjustments
        )

        refreshPrayerState(at: now, recalculateDayIfNeeded: false)
        isLoading = false

        // Save for widget
        let daily = DailyPrayerTimes(date: now, entries: prayerEntries, cityName: cityName, hijriDate: hijriDate)
        SharedDataManager.savePrayerTimes(daily)
        SharedDataManager.saveLocation(latitude: latitude, longitude: longitude, cityName: cityName, countryCode: countryCode)
        SharedDataManager.saveManualAdjustments(manualAdjustments)
        SharedDataManager.reloadWidgets()
    }

    func refreshPrayerState(at now: Date = Date()) {
        refreshPrayerState(at: now, recalculateDayIfNeeded: true)
    }

    private func refreshPrayerState(at now: Date, recalculateDayIfNeeded: Bool) {
        if recalculateDayIfNeeded,
           let calculatedDate,
           !calendar.isDate(calculatedDate, inSameDayAs: now) {
            calculateToday(at: now)
            return
        }

        let adjacentDates = [-1, 0, 1].compactMap { calendar.date(byAdding: .day, value: $0, to: now) }
        let schedule = adjacentDates.flatMap { date in
            calculationService.calculatePrayerTimes(
                date: date,
                latitude: latitude,
                longitude: longitude,
                configuration: resolvedCalculationConfiguration,
                asrMethod: asrMethod,
                highLatitudeRule: highLatitudeRule,
                adjustments: manualAdjustments
            )
        }.sorted { $0.adjustedTime < $1.adjustedTime }

        var current = schedule.last(where: { $0.adjustedTime <= now })
        var next = schedule.first(where: { $0.adjustedTime > now })
        current?.isCurrent = true
        next?.isNext = true
        currentPrayer = current
        nextPrayer = next
        timeUntilNext = max(0, next?.adjustedTime.timeIntervalSince(now) ?? 0)

        prayerEntries = prayerEntries.map { entry in
            var updated = entry
            updated.isCurrent = current.map {
                $0.prayer == entry.prayer && abs($0.adjustedTime.timeIntervalSince(entry.adjustedTime)) < 1
            } ?? false
            updated.isNext = next.map {
                $0.prayer == entry.prayer && abs($0.adjustedTime.timeIntervalSince(entry.adjustedTime)) < 1
            } ?? false
            return updated
        }
    }

    func updateLocation(latitude: Double, longitude: Double, cityName: String, countryCode: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
        self.countryCode = countryCode
        calculateToday()

        Task { @MainActor in
            SignificantLocationChangeService.shared.startMonitoringIfAuthorized()
        }
    }

    func recalculate() {
        calculateToday()
    }

    func multiDayTimes() -> [[PrayerTimeEntry]] {
        calculationService.calculateMultipleDays(
            startDate: Date(),
            days: Constants.NotificationBudget.daysToScheduleAhead,
            latitude: latitude,
            longitude: longitude,
            configuration: resolvedCalculationConfiguration,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule,
            adjustments: manualAdjustments
        )
    }

    var qiblaDirection: Double {
        calculationService.qiblaDirection(latitude: latitude, longitude: longitude)
    }

    private func persistCalculationSettings() {
        guard persistsCalculationSettings else { return }
        CalculationSettingsStorage.save(calculationSettings, to: .standard)
        if let sharedDefaults = Constants.sharedDefaults {
            CalculationSettingsStorage.save(calculationSettings, to: sharedDefaults)
        }
        if let data = calculationSettingsData {
            NSUbiquitousKeyValueStore.default.set(data, forKey: CalculationSettingsStorage.iCloudKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
}
