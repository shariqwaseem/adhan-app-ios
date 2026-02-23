import Foundation
@preconcurrency import Adhan

protocol PrayerCalculationServiceProtocol: Sendable {
    func calculatePrayerTimes(
        date: Date,
        latitude: Double,
        longitude: Double,
        method: CalculationMethodInfo,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int]
    ) -> [PrayerTimeEntry]

    func calculateMultipleDays(
        startDate: Date,
        days: Int,
        latitude: Double,
        longitude: Double,
        method: CalculationMethodInfo,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int]
    ) -> [[PrayerTimeEntry]]

    func qiblaDirection(latitude: Double, longitude: Double) -> Double
}

struct PrayerCalculationService: PrayerCalculationServiceProtocol {

    func calculatePrayerTimes(
        date: Date,
        latitude: Double,
        longitude: Double,
        method: CalculationMethodInfo,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int]
    ) -> [PrayerTimeEntry] {
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month, .day], from: date)
        let dateComponents = DateComponents(
            calendar: cal,
            year: components.year,
            month: components.month,
            day: components.day
        )
        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        var params = calculationParameters(for: method)
        params.madhab = adhanMadhab(for: asrMethod)
        params.highLatitudeRule = adhanHighLatitudeRule(for: highLatitudeRule)

        guard let prayerTimes = PrayerTimes(coordinates: coordinates, date: dateComponents, calculationParameters: params) else {
            return []
        }

        let now = Date()

        // Calculate Tahajjud: last third of the night between previous Isha and today's Fajr
        let tahajjudTime: Date = {
            let fajr = prayerTimes.fajr
            // Get yesterday's Isha for the night calculation
            let cal = Calendar.current
            if let yesterday = cal.date(byAdding: .day, value: -1, to: date) {
                let yComponents = cal.dateComponents([.year, .month, .day], from: yesterday)
                let yDateComponents = DateComponents(calendar: cal, year: yComponents.year, month: yComponents.month, day: yComponents.day)
                if let yesterdayPrayers = PrayerTimes(coordinates: coordinates, date: yDateComponents, calculationParameters: params) {
                    let isha = yesterdayPrayers.isha
                    let nightDuration = fajr.timeIntervalSince(isha)
                    // Last third of the night = Isha + (2/3 of night duration)
                    return isha.addingTimeInterval(nightDuration * 2.0 / 3.0)
                }
            }
            // Fallback: estimate last third as 2 hours before Fajr
            return fajr.addingTimeInterval(-2 * 3600)
        }()

        var entries = [
            PrayerTimeEntry(prayer: .tahajjud, time: tahajjudTime, manualAdjustmentMinutes: adjustments[.tahajjud] ?? 0),
            PrayerTimeEntry(prayer: .fajr, time: prayerTimes.fajr, manualAdjustmentMinutes: adjustments[.fajr] ?? 0),
            PrayerTimeEntry(prayer: .dhuhr, time: prayerTimes.dhuhr, manualAdjustmentMinutes: adjustments[.dhuhr] ?? 0),
            PrayerTimeEntry(prayer: .asr, time: prayerTimes.asr, manualAdjustmentMinutes: adjustments[.asr] ?? 0),
            PrayerTimeEntry(prayer: .maghrib, time: prayerTimes.maghrib, manualAdjustmentMinutes: adjustments[.maghrib] ?? 0),
            PrayerTimeEntry(prayer: .isha, time: prayerTimes.isha, manualAdjustmentMinutes: adjustments[.isha] ?? 0),
        ]

        // Determine current and next prayer
        if cal.isDate(date, inSameDayAs: now) {
            for i in entries.indices {
                let adjustedTime = entries[i].adjustedTime
                let nextIndex = entries.index(after: i)
                let nextTime = nextIndex < entries.count ? entries[nextIndex].adjustedTime : nil

                if now >= adjustedTime && (nextTime == nil || now < nextTime!) {
                    entries[i].isCurrent = true
                    if let ni = nextTime, ni > now, nextIndex < entries.count {
                        entries[nextIndex].isNext = true
                    }
                }
            }

            // If before first prayer, first prayer is next
            if !entries.contains(where: { $0.isNext || $0.isCurrent }) {
                if let first = entries.first, now < first.adjustedTime {
                    entries[0].isNext = true
                }
            }

            // If after last prayer, no current/next for today
        }

        return entries
    }

    func calculateMultipleDays(
        startDate: Date,
        days: Int,
        latitude: Double,
        longitude: Double,
        method: CalculationMethodInfo,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int]
    ) -> [[PrayerTimeEntry]] {
        let cal = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return calculatePrayerTimes(
                date: date,
                latitude: latitude,
                longitude: longitude,
                method: method,
                asrMethod: asrMethod,
                highLatitudeRule: highLatitudeRule,
                adjustments: adjustments
            )
        }
    }

    func qiblaDirection(latitude: Double, longitude: Double) -> Double {
        let qibla = Qibla(coordinates: Coordinates(latitude: latitude, longitude: longitude))
        return qibla.direction
    }

    // MARK: - Private Mappings

    private func calculationParameters(for method: CalculationMethodInfo) -> CalculationParameters {
        switch method {
        case .MuslimWorldLeague:
            return CalculationMethod.muslimWorldLeague.params
        case .Egyptian:
            return CalculationMethod.egyptian.params
        case .Karachi:
            return CalculationMethod.karachi.params
        case .UmmAlQura:
            return CalculationMethod.ummAlQura.params
        case .Dubai:
            return CalculationMethod.dubai.params
        case .MoonsightingCommittee:
            return CalculationMethod.moonsightingCommittee.params
        case .NorthAmerica:
            return CalculationMethod.northAmerica.params
        case .Kuwait:
            return CalculationMethod.kuwait.params
        case .Qatar:
            return CalculationMethod.qatar.params
        case .Singapore:
            return CalculationMethod.singapore.params
        case .Tehran:
            return CalculationMethod.tehran.params
        case .Turkey:
            return CalculationMethod.turkey.params
        case .Other:
            return CalculationMethod.other.params
        }
    }

    private func adhanMadhab(for method: AsrJuristicMethod) -> Madhab {
        switch method {
        case .standard: return .shafi
        case .hanafi: return .hanafi
        }
    }

    private func adhanHighLatitudeRule(for rule: HighLatitudeRuleOption) -> HighLatitudeRule {
        switch rule {
        case .middleOfTheNight: return .middleOfTheNight
        case .seventhOfTheNight: return .seventhOfTheNight
        case .twilightAngle: return .twilightAngle
        }
    }
}
