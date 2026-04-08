import AppIntents

#if canImport(AlarmKit)
import AlarmKit

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
        return .result()
    }
}
#endif
