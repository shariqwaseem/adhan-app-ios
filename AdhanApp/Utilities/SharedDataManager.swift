import Foundation
import WidgetKit

struct SharedDataManager: Sendable {
    static func savePrayerTimes(_ dailyTimes: DailyPrayerTimes) {
        guard let defaults = Constants.sharedDefaults else { return }
        if let data = try? JSONEncoder().encode(dailyTimes) {
            defaults.set(data, forKey: Constants.Keys.cachedPrayerTimes)
        }
    }

    static func loadPrayerTimes() -> DailyPrayerTimes? {
        guard let defaults = Constants.sharedDefaults,
              let data = defaults.data(forKey: Constants.Keys.cachedPrayerTimes) else { return nil }
        return try? JSONDecoder().decode(DailyPrayerTimes.self, from: data)
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func saveLocation(latitude: Double, longitude: Double, cityName: String, countryCode: String?) {
        guard let defaults = Constants.sharedDefaults else { return }
        defaults.set(latitude, forKey: Constants.Keys.lastLocationLatitude)
        defaults.set(longitude, forKey: Constants.Keys.lastLocationLongitude)
        defaults.set(cityName, forKey: Constants.Keys.lastCityName)
        defaults.set(countryCode, forKey: Constants.Keys.lastCountryCode)
    }

    static func saveCalculationMethod(_ rawValue: String) {
        guard let defaults = Constants.sharedDefaults else { return }
        defaults.set(rawValue, forKey: Constants.Keys.calculationMethod)
    }

    static func saveCalculationSettings(_ payload: CalculationSettingsPayload) {
        guard let defaults = Constants.sharedDefaults else { return }
        CalculationSettingsStorage.save(payload, to: defaults)
    }

    static func loadCalculationSettings() -> CalculationSettingsPayload? {
        guard let defaults = Constants.sharedDefaults else { return nil }
        return CalculationSettingsStorage.load(from: defaults)
    }

    static func loadCalculationMethod() -> CalculationMethodInfo? {
        guard let rawValue = Constants.sharedDefaults?.string(forKey: Constants.Keys.calculationMethod) else {
            return nil
        }
        return CalculationMethodInfo(rawValue: rawValue)
    }

    static func saveAsrMethod(_ rawValue: String) {
        guard let defaults = Constants.sharedDefaults else { return }
        defaults.set(rawValue, forKey: Constants.Keys.asrMethod)
    }

    static func loadAsrMethod() -> AsrJuristicMethod? {
        guard let rawValue = Constants.sharedDefaults?.string(forKey: Constants.Keys.asrMethod) else {
            return nil
        }
        return AsrJuristicMethod(rawValue: rawValue)
    }

    static func saveHighLatitudeRule(_ rawValue: String) {
        guard let defaults = Constants.sharedDefaults else { return }
        defaults.set(rawValue, forKey: Constants.Keys.highLatitudeRule)
    }

    static func loadHighLatitudeRule() -> HighLatitudeRuleOption? {
        guard let rawValue = Constants.sharedDefaults?.string(forKey: Constants.Keys.highLatitudeRule) else {
            return nil
        }
        return HighLatitudeRuleOption(rawValue: rawValue)
    }

    static func saveManualAdjustments(_ adjustments: [PrayerName: Int]) {
        guard let defaults = Constants.sharedDefaults else { return }
        let stringKeyed = Dictionary(uniqueKeysWithValues: adjustments.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            defaults.set(data, forKey: Constants.Keys.manualAdjustments)
        }
    }

    static func loadManualAdjustments() -> [PrayerName: Int] {
        guard let defaults = Constants.sharedDefaults,
              let data = defaults.data(forKey: Constants.Keys.manualAdjustments),
              let stringKeyed = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: stringKeyed.compactMap { key, value in
            guard let prayer = PrayerName(rawValue: key) else { return nil }
            return (prayer, value)
        })
    }

    static func saveLanguage(_ languageCode: String) {
        guard let defaults = Constants.sharedDefaults else { return }
        defaults.set(languageCode, forKey: "appLanguage")
    }

    static func loadLocation() -> (latitude: Double, longitude: Double, cityName: String, countryCode: String?)? {
        guard let defaults = Constants.sharedDefaults else { return nil }
        let lat = defaults.double(forKey: Constants.Keys.lastLocationLatitude)
        let lon = defaults.double(forKey: Constants.Keys.lastLocationLongitude)
        guard lat != 0 || lon != 0 else { return nil }
        let city = defaults.string(forKey: Constants.Keys.lastCityName) ?? "Unknown"
        let country = defaults.string(forKey: Constants.Keys.lastCountryCode)
        return (lat, lon, city, country)
    }
}
