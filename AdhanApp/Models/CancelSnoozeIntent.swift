import AppIntents

#if canImport(AlarmKit)
import AlarmKit

@available(iOS 26, *)
struct StopAdhanAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Alarm"
    static let description = IntentDescription("Stop an Adhan alarm")

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        try AlarmManager.shared.stop(id: UUID(uuidString: alarmID)!)
        return .result()
//        guard let id = UUID(uuidString: alarmID) else {
//            await AlarmLiveActivityCleanup.endActivitiesWithoutCurrentAlarm()
//            return .result()
//        }
//
//        try? AlarmKit.AlarmManager.shared.stop(id: id)
//        await AlarmLiveActivityCleanup.endActivities(for: [id])
//        return .result()
    }
}

@available(iOS 26, *)
struct SnoozeAdhanAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze Alarm"
    static let description = IntentDescription("Snooze an Adhan alarm")

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else {
            return .result()
        }

        try? AlarmKit.AlarmManager.shared.countdown(id: id)
        return .result()
    }
}

@available(iOS 26, *)
struct CancelAlarmSnoozeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Alarm Snooze"
    static let isDiscoverable: Bool = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else {
            await AlarmLiveActivityCleanup.endActivitiesWithoutCurrentAlarm()
            return .result()
        }

        try? AlarmKit.AlarmManager.shared.cancel(id: id)
        await AlarmLiveActivityCleanup.endActivities(for: [id])
        return .result()
    }
}
#endif
