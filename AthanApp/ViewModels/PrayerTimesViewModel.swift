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

    // Current calculation parameters — persisted via UserDefaults
    var calculationMethod: CalculationMethodInfo = .MuslimWorldLeague {
        didSet {
            UserDefaults.standard.set(calculationMethod.rawValue, forKey: "calculationMethod")
            SharedDataManager.saveCalculationMethod(calculationMethod.rawValue)
        }
    }
    var asrMethod: AsrJuristicMethod = .standard {
        didSet { UserDefaults.standard.set(asrMethod.rawValue, forKey: "asrMethod") }
    }
    var highLatitudeRule: HighLatitudeRuleOption = .middleOfTheNight {
        didSet { UserDefaults.standard.set(highLatitudeRule.rawValue, forKey: "highLatitudeRule") }
    }

    var manualAdjustments: [PrayerName: Int] = [:]

    // Location
    var latitude: Double = 21.4225  // Mecca default
    var longitude: Double = 39.8262

    init(
        calculationService: PrayerCalculationServiceProtocol = PrayerCalculationService(),
        hijriDateService: HijriDateService = HijriDateService()
    ) {
        self.calculationService = calculationService
        self.hijriDateService = hijriDateService

        // Restore saved calculation settings
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "calculationMethod"),
           let method = CalculationMethodInfo(rawValue: raw) {
            self.calculationMethod = method
        }
        // Sync to shared defaults for the widget
        SharedDataManager.saveCalculationMethod(calculationMethod.rawValue)
        if let raw = defaults.string(forKey: "asrMethod"),
           let method = AsrJuristicMethod(rawValue: raw) {
            self.asrMethod = method
        }
        if let raw = defaults.string(forKey: "highLatitudeRule"),
           let rule = HighLatitudeRuleOption(rawValue: raw) {
            self.highLatitudeRule = rule
        }

        // Restore last saved location
        if let saved = SharedDataManager.loadLocation() {
            self.latitude = saved.latitude
            self.longitude = saved.longitude
            self.cityName = saved.cityName
            self.countryCode = saved.countryCode
        }
    }

    func calculateToday() {
        let now = Date()
        hijriDate = hijriDateService.hijriDateString(for: now)

        prayerEntries = calculationService.calculatePrayerTimes(
            date: now,
            latitude: latitude,
            longitude: longitude,
            method: calculationMethod,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule,
            adjustments: manualAdjustments
        )

        updateCurrentAndNext()
        isLoading = false

        // Save for widget
        let daily = DailyPrayerTimes(date: now, entries: prayerEntries, cityName: cityName, hijriDate: hijriDate)
        SharedDataManager.savePrayerTimes(daily)
        SharedDataManager.saveLocation(latitude: latitude, longitude: longitude, cityName: cityName, countryCode: countryCode)
        SharedDataManager.reloadWidgets()
    }

    func updateCurrentAndNext() {
        let now = Date()
        currentPrayer = prayerEntries.first(where: { $0.isCurrent })
        nextPrayer = prayerEntries.first(where: { $0.isNext })

        // If no next prayer today, get tomorrow's fajr
        if nextPrayer == nil && (currentPrayer != nil || prayerEntries.allSatisfy({ $0.adjustedTime < now })) {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
            let tomorrowEntries = calculationService.calculatePrayerTimes(
                date: tomorrow,
                latitude: latitude,
                longitude: longitude,
                method: calculationMethod,
                asrMethod: asrMethod,
                highLatitudeRule: highLatitudeRule,
                adjustments: manualAdjustments
            )
            if let fajr = tomorrowEntries.first {
                nextPrayer = PrayerTimeEntry(prayer: fajr.prayer, time: fajr.time, isNext: true, manualAdjustmentMinutes: fajr.manualAdjustmentMinutes)
            }
        }

        if let next = nextPrayer {
            timeUntilNext = next.adjustedTime.timeIntervalSince(now)
        }
    }

    func updateLocation(latitude: Double, longitude: Double, cityName: String, countryCode: String?, autoSetCalculationMethod: Bool = false) {
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
        self.countryCode = countryCode

        if autoSetCalculationMethod, let code = countryCode {
            self.calculationMethod = CalculationMethodInfo.recommendedMethod(forCountryCode: code)
        }
        calculateToday()
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
            method: calculationMethod,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule,
            adjustments: manualAdjustments
        )
    }

    var qiblaDirection: Double {
        calculationService.qiblaDirection(latitude: latitude, longitude: longitude)
    }
}
