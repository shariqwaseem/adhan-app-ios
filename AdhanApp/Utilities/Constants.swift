import Foundation

enum Constants {
    static let appGroupIdentifier = "group.shariq.adhanapp.com"
    static let backgroundRefreshIdentifier = "com.shariq.adhanapp.refresh"
    static let iCloudKeyValueStoreIdentifier = "com.shariq.adhanapp"

    nonisolated(unsafe) static let sharedDefaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)

    static let processingTaskIdentifier = "com.shariq.adhanapp.processing"

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
