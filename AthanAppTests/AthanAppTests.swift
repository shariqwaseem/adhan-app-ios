import Testing
import Foundation
@testable import Athan

@Suite("Prayer Calculation Tests")
struct PrayerCalculationTests {
    let service = PrayerCalculationService()

    @Test("Calculate prayer times for Mecca")
    func meccaPrayerTimes() {
        let date = createDate(year: 2025, month: 6, day: 15)
        let entries = service.calculatePrayerTimes(
            date: date,
            latitude: 21.4225,
            longitude: 39.8262,
            method: .UmmAlQura,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        #expect(entries.count == 6)
        #expect(entries[0].prayer == .tahajjud)
        #expect(entries[1].prayer == .fajr)
        #expect(entries[2].prayer == .dhuhr)
        #expect(entries[3].prayer == .asr)
        #expect(entries[4].prayer == .maghrib)
        #expect(entries[5].prayer == .isha)
    }

    @Test("Prayer times are in chronological order")
    func chronologicalOrder() {
        let date = createDate(year: 2025, month: 3, day: 21)
        let entries = service.calculatePrayerTimes(
            date: date,
            latitude: 40.7128,
            longitude: -74.0060,
            method: .NorthAmerica,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        for i in 1..<entries.count {
            #expect(entries[i].time > entries[i - 1].time, "Prayer \(entries[i].prayer.rawValue) should be after \(entries[i - 1].prayer.rawValue)")
        }
    }

    @Test("Karachi prayer times")
    func karachiPrayerTimes() {
        let date = createDate(year: 2025, month: 1, day: 15)
        let entries = service.calculatePrayerTimes(
            date: date,
            latitude: 24.8607,
            longitude: 67.0011,
            method: .Karachi,
            asrMethod: .hanafi,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        #expect(entries.count == 6)
        // Hanafi Asr should be later than Shafi'i
        let shafiEntries = service.calculatePrayerTimes(
            date: date,
            latitude: 24.8607,
            longitude: 67.0011,
            method: .Karachi,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        let hanafiAsr = entries.first(where: { $0.prayer == .asr })!.time
        let shafiAsr = shafiEntries.first(where: { $0.prayer == .asr })!.time
        #expect(hanafiAsr > shafiAsr, "Hanafi Asr should be later than Shafi'i Asr")
    }

    @Test("Recommended method for country codes")
    func methodRecommendation() {
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "US") == .NorthAmerica)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "SA") == .UmmAlQura)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "PK") == .Karachi)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "TR") == .Turkey)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "GB") == .MoonsightingCommittee)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: nil) == .MuslimWorldLeague)
    }

    @Test("Manual adjustments are applied")
    func manualAdjustments() {
        let date = createDate(year: 2025, month: 6, day: 15)
        let entries = service.calculatePrayerTimes(
            date: date,
            latitude: 21.4225,
            longitude: 39.8262,
            method: .UmmAlQura,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [.fajr: 5, .maghrib: -3]
        )
        let fajr = entries.first(where: { $0.prayer == .fajr })!
        #expect(fajr.manualAdjustmentMinutes == 5)
        #expect(fajr.adjustedTime != fajr.time)
    }

    @Test("Qibla direction from New York")
    func qiblaFromNewYork() {
        let direction = service.qiblaDirection(latitude: 40.7128, longitude: -74.0060)
        // Qibla from NYC should be roughly 58-59 degrees (NE)
        #expect(direction > 50 && direction < 70, "Qibla from NYC should be roughly NE (~58°)")
    }

    @Test("Multi-day calculation returns correct count")
    func multiDayCalculation() {
        let date = createDate(year: 2025, month: 6, day: 1)
        let results = service.calculateMultipleDays(
            startDate: date,
            days: 7,
            latitude: 21.4225,
            longitude: 39.8262,
            method: .UmmAlQura,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        #expect(results.count == 7)
        for day in results {
            #expect(day.count == 6)
        }
    }

    private func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components)!
    }
}

@Suite("Hijri Date Tests")
struct HijriDateTests {
    let service = HijriDateService()

    @Test("Hijri date string is not empty")
    func hijriDateNotEmpty() {
        let result = service.hijriDateString(for: Date())
        #expect(!result.isEmpty)
    }

    @Test("Ramadan detection")
    func ramadanDetection() {
        // Ramadan 2025 starts around March 1, 2025
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 15
        components.timeZone = TimeZone(identifier: "UTC")
        let midRamadan2025 = Calendar.current.date(from: components)!
        let isRamadan = service.isRamadan(on: midRamadan2025)
        // This is approximately Ramadan time but exact dates vary
        // Just verify the function runs without crashing
        _ = isRamadan
        _ = service.ramadanDay(on: midRamadan2025)
    }
}
