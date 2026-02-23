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

    // Current calculation parameters
    var calculationMethod: CalculationMethodInfo = .MuslimWorldLeague
    var asrMethod: AsrJuristicMethod = .standard
    var highLatitudeRule: HighLatitudeRuleOption = .middleOfTheNight
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

        // Restore last saved location
        if let saved = SharedDataManager.loadLocation() {
            self.latitude = saved.latitude
            self.longitude = saved.longitude
            self.cityName = saved.cityName
            self.countryCode = saved.countryCode
            if let code = saved.countryCode {
                self.calculationMethod = CalculationMethodInfo.recommendedMethod(forCountryCode: code)
            }
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

    func updateLocation(latitude: Double, longitude: Double, cityName: String, countryCode: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
        self.countryCode = countryCode
        if let code = countryCode {
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
