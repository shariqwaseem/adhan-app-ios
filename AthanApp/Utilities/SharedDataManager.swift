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
        defaults.set(rawValue, forKey: "calculationMethod")
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
