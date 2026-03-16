import Foundation

enum Constants {
    static let appGroupIdentifier = "group.com.adhanshariq.app"
    static let backgroundRefreshIdentifier = "com.adhanshariq.app.refresh"
    static let iCloudKeyValueStoreIdentifier = "com.adhanshariq.app"

    nonisolated(unsafe) static let sharedDefaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)

    static let processingTaskIdentifier = "com.adhanshariq.app.processing"

    enum Keys {
        static let cachedPrayerTimes = "cachedPrayerTimes"
        static let lastLocationLatitude = "lastLocationLatitude"
        static let lastLocationLongitude = "lastLocationLongitude"
        static let lastCityName = "lastCityName"
        static let lastCountryCode = "lastCountryCode"
        static let lastBackgroundRefreshDate = "lastBackgroundRefreshDate"
        static let nextAlarmFireTime = "nextAlarmFireTime"
    }

    enum NotificationBudget {
        static let maxPendingNotifications = 64
        static let daysToScheduleAhead = 10  // floor(64/6) = 10 days = 60 notifications
        static let prayerCount = 6
    }
}
