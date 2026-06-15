import Foundation

#if canImport(AlarmKit)
import AlarmKit
import ActivityKit

@available(iOS 26, *)
struct AdhanAlarmMetadata: AlarmMetadata {
    var prayerName: String
    var prayerTime: Date
}

@available(iOS 26, *)
enum AlarmLiveActivityCleanup {
    static func endActivitiesWithoutCurrentAlarm() async {
        let alarms: [AlarmKit.Alarm]
        do {
            alarms = try AlarmKit.AlarmManager.shared.alarms
        } catch {
            return
        }

        await endActivities(notMatching: activeActivityAlarmIDs(from: alarms))
    }

    static func endActivitiesWithoutCurrentAlarm(in alarms: [AlarmKit.Alarm]) async {
        await endActivities(notMatching: activeActivityAlarmIDs(from: alarms))
    }

    static func endActivities(for alarmIDs: some Sequence<AlarmKit.Alarm.ID>) async {
        let alarmIDs = Set(alarmIDs)
        guard !alarmIDs.isEmpty else { return }

        for activity in Activity<AlarmAttributes<AdhanAlarmMetadata>>.activities
        where alarmIDs.contains(activity.content.state.alarmID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func endAllActivities() async {
        for activity in Activity<AlarmAttributes<AdhanAlarmMetadata>>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func endActivities(notMatching activeAlarmIDs: Set<AlarmKit.Alarm.ID>) async {
        for activity in Activity<AlarmAttributes<AdhanAlarmMetadata>>.activities {
            switch activity.activityState {
            case .ended, .dismissed:
                continue
            default:
                break
            }

            if !activeAlarmIDs.contains(activity.content.state.alarmID) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func activeActivityAlarmIDs(from alarms: [AlarmKit.Alarm]) -> Set<AlarmKit.Alarm.ID> {
        Set(alarms.compactMap { alarm in
            switch alarm.state {
            case .alerting, .countdown:
                return alarm.id
            case .scheduled, .paused:
                return nil
            @unknown default:
                return nil
            }
        })
    }
}
#endif
