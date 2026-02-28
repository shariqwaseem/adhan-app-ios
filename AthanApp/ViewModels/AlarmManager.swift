import Foundation
import Observation

#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
#endif

@Observable
@MainActor
final class AthanAlarmManager {
    var isAuthorized: Bool = false
    var authError: String? = nil
    var scheduledAlarmIDs: [String: [UUID]] = [:]  // prayerName -> alarm UUIDs (one per scheduled day)

    nonisolated static var isAlarmSupported: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    #if canImport(AlarmKit)
    @available(iOS 26, *)
    nonisolated private var _manager: AlarmKit.AlarmManager {
        AlarmKit.AlarmManager.shared
    }
    #endif

    func requestAuthorization() async {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            do {
                let state = try await _manager.requestAuthorization()
                isAuthorized = state == .authorized
                if !isAuthorized {
                    authError = "Alarm permission denied. Go to Settings > Apps > Athan to enable."
                }
            } catch {
                isAuthorized = false
                authError = "Alarm auth error: \(error.localizedDescription)"
            }
            return
        }
        #endif
        isAuthorized = false
        authError = "Alarm mode requires iOS 26 or later."
    }

    func checkAuthorization() {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            isAuthorized = _manager.authorizationState == .authorized
            return
        }
        #endif
        isAuthorized = false
    }

    /// Schedule an alarm for a prayer at the given date.
    func scheduleAlarm(
        for prayer: PrayerName,
        at prayerTime: Date,
        audioFileName: String? = nil
    ) async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            if !isAuthorized {
                await requestAuthorization()
            }
            guard isAuthorized else {
                throw AlarmScheduleError.notAuthorized(authError ?? "Alarm permission not granted")
            }

            let alarmID = UUID()

            let bundle = LanguageManager.shared.bundle
            let prayerTitle = String(localized: "\(prayer.localizedName) Prayer", bundle: bundle)
            let stopText = String(localized: "Stop", bundle: bundle)

            let presentation = AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: prayerTitle),
                    stopButton: AlarmButton(
                        text: LocalizedStringResource(stringLiteral: stopText),
                        textColor: .white,
                        systemImageName: "stop.fill"
                    )
                )
            )

            let attributes = AlarmAttributes<AthanAlarmMetadata>(
                presentation: presentation,
                metadata: AthanAlarmMetadata(prayerName: prayer.rawValue, prayerTime: prayerTime),
                tintColor: .green
            )

            let sound: AlertConfiguration.AlertSound
            if let name = audioFileName, !name.isEmpty {
                sound = .named(name)
            } else {
                sound = .default
            }

            let configuration = AlarmKit.AlarmManager.AlarmConfiguration.alarm(
                schedule: .fixed(prayerTime),
                attributes: attributes,
                sound: sound
            )

            _ = try await _manager.schedule(id: alarmID, configuration: configuration)
            scheduledAlarmIDs[prayer.rawValue, default: []].append(alarmID)
            return
        }
        #endif
        throw AlarmScheduleError.notAuthorized("Alarm mode requires iOS 26 or later.")
    }

    /// Schedule an alarm for a custom alarm entry.
    func scheduleCustomAlarm(
        id: UUID,
        title: String,
        at alarmTime: Date,
        audioFileName: String? = nil
    ) async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            if !isAuthorized {
                await requestAuthorization()
            }
            guard isAuthorized else {
                throw AlarmScheduleError.notAuthorized(authError ?? "Alarm permission not granted")
            }

            let alarmID = UUID()

            let bundle = LanguageManager.shared.bundle
            let stopText = String(localized: "Stop", bundle: bundle)

            let presentation = AlarmPresentation(
                alert: AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: title),
                    stopButton: AlarmButton(
                        text: LocalizedStringResource(stringLiteral: stopText),
                        textColor: .white,
                        systemImageName: "stop.fill"
                    )
                )
            )

            let attributes = AlarmAttributes<AthanAlarmMetadata>(
                presentation: presentation,
                metadata: AthanAlarmMetadata(prayerName: "custom_\(id.uuidString)", prayerTime: alarmTime),
                tintColor: .green
            )

            let sound: AlertConfiguration.AlertSound
            if let name = audioFileName, !name.isEmpty {
                sound = .named(name)
            } else {
                sound = .default
            }

            let configuration = AlarmKit.AlarmManager.AlarmConfiguration.alarm(
                schedule: .fixed(alarmTime),
                attributes: attributes,
                sound: sound
            )

            _ = try await _manager.schedule(id: alarmID, configuration: configuration)
            let trackingKey = "custom_\(id.uuidString)"
            scheduledAlarmIDs[trackingKey, default: []].append(alarmID)
            return
        }
        #endif
        throw AlarmScheduleError.notAuthorized("Alarm mode requires iOS 26 or later.")
    }

    /// Schedule a pre-alarm that fires before a prayer, with 5-minute snooze support.
    func schedulePreAlarm(
        for prayer: PrayerName,
        at preAlarmTime: Date,
        minutesBefore: Int,
        audioFileName: String? = nil
    ) async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            if !isAuthorized {
                await requestAuthorization()
            }
            guard isAuthorized else {
                throw AlarmScheduleError.notAuthorized(authError ?? "Alarm permission not granted")
            }

            let alarmID = UUID()

            let bundle = LanguageManager.shared.bundle
            let title = String(localized: "\(prayer.localizedName) in \(minutesBefore) min", bundle: bundle)
            let stopText = String(localized: "Stop", bundle: bundle)
            let snoozeText = String(localized: "Snooze", bundle: bundle)
            let snoozeCountdownTitle = String(localized: "Snoozing — \(prayer.localizedName) pre-alarm", bundle: bundle)

            let stopButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: stopText),
                textColor: .white,
                systemImageName: "stop.fill"
            )

            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                stopButton: stopButton,
                secondaryButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: snoozeText),
                    textColor: .white,
                    systemImageName: "moon.zzz"
                ),
                secondaryButtonBehavior: .countdown
            )

            let countdown = AlarmPresentation.Countdown(
                title: LocalizedStringResource(stringLiteral: snoozeCountdownTitle),
                stopButton: stopButton
            )

            let presentation = AlarmPresentation(
                alert: alert,
                countdown: countdown
            )

            let attributes = AlarmAttributes<AthanAlarmMetadata>(
                presentation: presentation,
                metadata: AthanAlarmMetadata(prayerName: "\(prayer.rawValue)_prealarm", prayerTime: preAlarmTime),
                tintColor: .orange
            )

            let sound: AlertConfiguration.AlertSound
            if let name = audioFileName, !name.isEmpty {
                sound = .named(name)
            } else {
                sound = .default
            }

            let snoozeDuration: TimeInterval = 5 * 60  // 5 minutes
            let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
                schedule: .fixed(preAlarmTime),
                countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: snoozeDuration),
                attributes: attributes,
                sound: sound
            )

            _ = try await _manager.schedule(id: alarmID, configuration: configuration)
            let trackingKey = "\(prayer.rawValue)_prealarm"
            scheduledAlarmIDs[trackingKey, default: []].append(alarmID)
            return
        }
        #endif
        throw AlarmScheduleError.notAuthorized("Alarm mode requires iOS 26 or later.")
    }

    /// Cancel all alarms for a specific prayer.
    func cancelAlarm(for prayer: PrayerName) {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            if let alarmIDs = scheduledAlarmIDs[prayer.rawValue] {
                for alarmID in alarmIDs {
                    try? _manager.cancel(id: alarmID)
                }
            }
        }
        #endif
        scheduledAlarmIDs.removeValue(forKey: prayer.rawValue)
    }

    /// Cancel all scheduled athan alarms.
    func cancelAll() {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            if let alarms = try? _manager.alarms {
                for alarm in alarms {
                    try? _manager.cancel(id: alarm.id)
                }
            }
        }
        #endif
        scheduledAlarmIDs.removeAll()
    }
}

enum AlarmScheduleError: LocalizedError {
    case notAuthorized(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized(let msg): return msg
        }
    }
}
