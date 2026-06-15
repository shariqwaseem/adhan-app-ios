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
        guard let id = UUID(uuidString: alarmID) else {
            await AlarmLiveActivityCleanup.endActivitiesWithoutCurrentAlarm()
            return .result()
        }

        try? AlarmKit.AlarmManager.shared.stop(id: id)
        await AlarmLiveActivityCleanup.endActivities(for: [id])
        return .result()
    }
}

@available(iOS 26, *)
struct CancelAlarmSnoozeIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Alarm Snooze"
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        let mgr = AlarmKit.AlarmManager.shared
        if let alarms = try? mgr.alarms {
            for alarm in alarms {
                try? mgr.cancel(id: alarm.id)
            }
        }
        await AlarmLiveActivityCleanup.endAllActivities()
        return .result()
    }
}
#endif
