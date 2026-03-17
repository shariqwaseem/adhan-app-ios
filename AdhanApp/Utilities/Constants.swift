import Foundation

enum Constants {
    static let appGroupIdentifier = "group.com.shariq.adhan"
    static let backgroundRefreshIdentifier = "com.shariq.adhan.refresh"
    static let iCloudKeyValueStoreIdentifier = "com.shariq.adhan"

    nonisolated(unsafe) static let sharedDefaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)

    static let processingTaskIdentifier = "com.shariq.adhan.processing"

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
