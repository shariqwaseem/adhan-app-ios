import Foundation

enum Constants {
    static let appGroupIdentifier = "group.com.athanapp.shared"
    static let backgroundRefreshIdentifier = "com.athanapp.refresh"
    static let iCloudKeyValueStoreIdentifier = "com.athanapp.app"

    nonisolated(unsafe) static let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

    enum Keys {
        static let cachedPrayerTimes = "cachedPrayerTimes"
        static let lastLocationLatitude = "lastLocationLatitude"
        static let lastLocationLongitude = "lastLocationLongitude"
        static let lastCityName = "lastCityName"
        static let lastCountryCode = "lastCountryCode"
    }

    enum NotificationBudget {
        static let maxPendingNotifications = 64
        static let daysToScheduleAhead = 7
        static let prayerCount = 6
    }
}
