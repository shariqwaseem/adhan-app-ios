import Foundation
import os.log
@preconcurrency import Adhan

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

protocol PrayerCalculationServiceProtocol: Sendable {
    func calculatePrayerTimes(
        date: Date,
        latitude: Double,
        longitude: Double,
        configuration: ResolvedCalculationConfiguration,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int]
    ) -> [PrayerTimeEntry]

    func calculateMultipleDays(
        startDate: Date,
        days: Int,
        latitude: Double,
        longitude: Double,
        configuration: ResolvedCalculationConfiguration,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int]
    ) -> [[PrayerTimeEntry]]

    func qiblaDirection(latitude: Double, longitude: Double) -> Double
}

struct PrayerCalculationService: PrayerCalculationServiceProtocol {
    private let calendar: Calendar
    private let core: PrayerCalculationCore

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        self.core = PrayerCalculationCore(calendar: calendar)
    }

    func calculatePrayerTimes(
        date: Date,
        latitude: Double,
        longitude: Double,
        configuration: ResolvedCalculationConfiguration,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int]
    ) -> [PrayerTimeEntry] {
        let entries = core.calculate(
            date: date,
            latitude: latitude,
            longitude: longitude,
            configuration: configuration,
            asrMethod: asrMethod,
            highLatitudeRule: highLatitudeRule
        ).map { base in
            PrayerTimeEntry(
                prayer: base.prayer,
                time: base.time,
                manualAdjustmentMinutes: adjustments[base.prayer] ?? 0
            )
        }

        // Log all computed prayer times
        let tf = DateFormatter()
        tf.dateFormat = "yyyy-MM-dd HH:mm:ss"
        tf.timeZone = calendar.timeZone
        let timesLog = entries.map { "\($0.prayer.rawValue)=\(tf.string(from: $0.adjustedTime))" }.joined(separator: ", ")
        AppLogger.calculation.info("Prayer times for \(tf.string(from: date)) at (\(latitude), \(longitude)) method=\(configuration.logName): \(timesLog)")

        // Flag anomaly: Isha between midnight and 3 AM at non-extreme latitudes
        if let isha = entries.first(where: { $0.prayer == .isha })?.time,
           abs(latitude) < 50,
           (0..<3).contains(calendar.component(.hour, from: isha)) {
            AppLogger.calculation.error("ANOMALY: Isha at \(tf.string(from: isha)) — unexpected for latitude \(latitude)")
            #if canImport(FirebaseCrashlytics)
            let anomalyError = NSError(domain: "com.shariqw.adhanpro.anomaly", code: 1, userInfo: [
                "prayer": "Isha",
                "time": tf.string(from: isha),
                "latitude": latitude,
                "longitude": longitude,
                "method": configuration.logName
            ])
            Crashlytics.crashlytics().record(error: anomalyError)
            #endif
            #if canImport(FirebaseAnalytics)
            Analytics.logEvent("prayer_time_anomaly", parameters: [
                "prayer": "Isha",
                "isha_time": tf.string(from: isha),
                "latitude": latitude,
                "longitude": longitude,
                "method": configuration.logName
            ])
            #endif
        }

        #if canImport(FirebaseCrashlytics)
        let crashlytics = Crashlytics.crashlytics()
        if let isha = entries.first(where: { $0.prayer == .isha })?.time {
            crashlytics.setCustomValue(tf.string(from: isha), forKey: "last_computed_isha")
        }
        if let fajr = entries.first(where: { $0.prayer == .fajr })?.time {
            crashlytics.setCustomValue(tf.string(from: fajr), forKey: "last_computed_fajr")
        }
        crashlytics.setCustomValue("\(latitude),\(longitude)", forKey: "last_coordinates")
        crashlytics.setCustomValue(configuration.logName, forKey: "last_calc_method")
        #endif
        return entries
    }

    func calculateMultipleDays(
        startDate: Date,
        days: Int,
        latitude: Double,
        longitude: Double,
        configuration: ResolvedCalculationConfiguration,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int]
    ) -> [[PrayerTimeEntry]] {
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return calculatePrayerTimes(
                date: date,
                latitude: latitude,
                longitude: longitude,
                configuration: configuration,
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
}
