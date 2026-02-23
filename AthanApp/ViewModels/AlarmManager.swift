import Foundation
import Observation
import AlarmKit

@Observable
@MainActor
final class AthanAlarmManager {
    var isAuthorized: Bool = false
    var scheduledAlarmIDs: [String: UUID] = [:]  // prayerName -> alarm UUID

    nonisolated(unsafe) private let manager = AlarmKit.AlarmManager.shared

    func requestAuthorization() async {
        do {
            let state = try await manager.requestAuthorization()
            isAuthorized = state == .authorized
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorization() {
        isAuthorized = manager.authorizationState == .authorized
    }

    /// Schedule an alarm for a prayer at the given date, with an optional offset in minutes before.
    func scheduleAlarm(
        for prayer: PrayerName,
        at prayerTime: Date,
        offsetMinutes: Int = 0
    ) async throws {
        let alarmTime: Date
        if offsetMinutes > 0 {
            alarmTime = Calendar.current.date(byAdding: .minute, value: -offsetMinutes, to: prayerTime) ?? prayerTime
        } else {
            alarmTime = prayerTime
        }

        // Cancel existing alarm for this prayer if any
        cancelAlarm(for: prayer)

        let alarmID = UUID()

        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: "\(prayer.localizedName) Prayer"),
                stopButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: "Stop"),
                    textColor: .white,
                    systemImageName: "stop.fill"
                ),
                secondaryButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: "Snooze"),
                    textColor: .white,
                    systemImageName: "clock.fill"
                ),
                secondaryButtonBehavior: .countdown
            )
        )

        let attributes = AlarmAttributes<AthanAlarmMetadata>(
            presentation: presentation,
            metadata: AthanAlarmMetadata(prayerName: prayer.rawValue, prayerTime: prayerTime),
            tintColor: .green
        )

        let configuration = AlarmKit.AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(alarmTime),
            attributes: attributes
        )

        _ = try await manager.schedule(id: alarmID, configuration: configuration)
        scheduledAlarmIDs[prayer.rawValue] = alarmID
    }

    /// Cancel alarm for a specific prayer.
    func cancelAlarm(for prayer: PrayerName) {
        guard let alarmID = scheduledAlarmIDs[prayer.rawValue] else { return }
        try? manager.cancel(id: alarmID)
        scheduledAlarmIDs.removeValue(forKey: prayer.rawValue)
    }

    /// Cancel all scheduled athan alarms.
    func cancelAll() {
        for (_, alarmID) in scheduledAlarmIDs {
            try? manager.cancel(id: alarmID)
        }
        scheduledAlarmIDs.removeAll()
    }

    /// Get the current list of active alarms from AlarmKit.
    func activeAlarms() -> [Alarm] {
        (try? manager.alarms) ?? []
    }
}
