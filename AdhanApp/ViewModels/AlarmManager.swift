import Foundation
import Observation
import os.log

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
#endif

@Observable
@MainActor
final class AdhanAlarmManager {
    var isAuthorized: Bool = false
    var authError: String? = nil
    var scheduledAlarmIDs: [String: [UUID]] = [:]  // prayerName -> alarm UUIDs (one per scheduled day)
    @ObservationIgnored private var autoStopObserverTask: Task<Void, Never>?
    @ObservationIgnored private var autoStopTasks: [UUID: Task<Void, Never>] = [:]

    nonisolated private static let maxAlertDurationSeconds: TimeInterval = 5 * 60

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

    init() {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            startObservingAlarmState()
        }
        #endif
    }

    func requestAuthorization() async {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            do {
                let state = try await _manager.requestAuthorization()
                isAuthorized = state == .authorized
                if !isAuthorized {
                    authError = "Alarm permission denied. Go to Settings > Apps > Adhan to enable."
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
        if UserDefaults.standard.bool(forKey: "FASTLANE_SCREENSHOTS") {
            isAuthorized = true
            authError = nil
            return
        }
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            isAuthorized = _manager.authorizationState == .authorized
            return
        }
        #endif
        isAuthorized = false
    }

    // MARK: - Presentation Helper

    #if canImport(AlarmKit)
    @available(iOS 26, *)
    private nonisolated func makePresentation(
        alertTitle: String,
        snoozeCountdownTitle: String
    ) -> AlarmPresentation {
        let bundle = LanguageManager.shared.bundle
        let stopText = String(localized: "Stop", bundle: bundle)
        let snoozeText = String(localized: "Snooze", bundle: bundle)

        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: stopText),
            textColor: .white,
            systemImageName: "xmark"
        )

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alertTitle),
            stopButton: stopButton,
            secondaryButton: AlarmButton(
                text: LocalizedStringResource(stringLiteral: snoozeText),
                textColor: .white,
                systemImageName: "moon.zzz"
            ),
            secondaryButtonBehavior: .countdown
        )

        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: snoozeCountdownTitle)
        )

        return AlarmPresentation(alert: alert, countdown: countdown)
    }
    #endif

    /// Schedule an alarm for a prayer at the given date.
    func scheduleAlarm(
        for prayer: PrayerName,
        at prayerTime: Date,
        audioFileName: String? = nil
    ) async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            AppLogger.alarm.info("scheduleAlarm: \(prayer.rawValue) at \(prayerTime.formatted(date: .abbreviated, time: .standard))")

            if !isAuthorized {
                await requestAuthorization()
            }
            guard isAuthorized else {
                let msg = authError ?? "Alarm permission not granted"
                AppLogger.alarm.error("scheduleAlarm: not authorized — \(msg)")
                throw AlarmScheduleError.notAuthorized(msg)
            }

            let alarmID = UUID()
            let bundle = LanguageManager.shared.bundle
            let prayerTitle = String(localized: "\(prayer.localizedName) Prayer", bundle: bundle)
            let snoozeCountdownTitle = String(localized: "Snoozing — \(prayer.localizedName) Prayer", bundle: bundle)

            let presentation = makePresentation(
                alertTitle: prayerTitle,
                snoozeCountdownTitle: snoozeCountdownTitle
            )

            let attributes = AlarmAttributes<AdhanAlarmMetadata>(
                presentation: presentation,
                metadata: AdhanAlarmMetadata(prayerName: prayer.rawValue, prayerTime: prayerTime),
                tintColor: .green
            )

            let sound: AlertConfiguration.AlertSound
            if let name = audioFileName, !name.isEmpty {
                sound = .named(name)
            } else {
                sound = .default
            }

            let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
                countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: Self.maxAlertDurationSeconds),
                schedule: .fixed(prayerTime),
                attributes: attributes,
                stopIntent: StopAdhanAlarmIntent(alarmID: alarmID.uuidString),
                sound: sound
            )

            _ = try await _manager.schedule(id: alarmID, configuration: configuration)
            scheduledAlarmIDs[prayer.rawValue, default: []].append(alarmID)
            AppLogger.alarm.info("scheduleAlarm: \(prayer.rawValue) scheduled with UUID \(alarmID) at \(prayerTime.formatted(date: .abbreviated, time: .standard))")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().setCustomValue(prayerTime.timeIntervalSince1970, forKey: "last_\(prayer.rawValue)_alarm_time")
            #endif
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
            let snoozeCountdownTitle = String(localized: "Snoozing — \(title)", bundle: bundle)

            let presentation = makePresentation(
                alertTitle: title,
                snoozeCountdownTitle: snoozeCountdownTitle
            )

            let attributes = AlarmAttributes<AdhanAlarmMetadata>(
                presentation: presentation,
                metadata: AdhanAlarmMetadata(prayerName: "custom_\(id.uuidString)", prayerTime: alarmTime),
                tintColor: .green
            )

            let sound: AlertConfiguration.AlertSound
            if let name = audioFileName, !name.isEmpty {
                sound = .named(name)
            } else {
                sound = .default
            }

            let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
                countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: Self.maxAlertDurationSeconds),
                schedule: .fixed(alarmTime),
                attributes: attributes,
                stopIntent: StopAdhanAlarmIntent(alarmID: alarmID.uuidString),
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

    /// Schedule a pre-alarm that fires before a prayer.
    func schedulePreAlarm(
        for prayer: PrayerName,
        at preAlarmTime: Date,
        minutesBefore: Int
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
            let snoozeCountdownTitle = String(localized: "Snoozing — \(prayer.localizedName) pre-alarm", bundle: bundle)

            let presentation = makePresentation(
                alertTitle: title,
                snoozeCountdownTitle: snoozeCountdownTitle
            )

            let attributes = AlarmAttributes<AdhanAlarmMetadata>(
                presentation: presentation,
                metadata: AdhanAlarmMetadata(prayerName: "\(prayer.rawValue)_prealarm", prayerTime: preAlarmTime),
                tintColor: .orange
            )

            let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
                countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: Self.maxAlertDurationSeconds),
                schedule: .fixed(preAlarmTime),
                attributes: attributes,
                stopIntent: StopAdhanAlarmIntent(alarmID: alarmID.uuidString),
                sound: .default
            )

            _ = try await _manager.schedule(id: alarmID, configuration: configuration)
            let trackingKey = "\(prayer.rawValue)_prealarm"
            scheduledAlarmIDs[trackingKey, default: []].append(alarmID)
            return
        }
        #endif
        throw AlarmScheduleError.notAuthorized("Alarm mode requires iOS 26 or later.")
    }

    /// Schedule a pre-alarm for a custom alarm.
    func scheduleCustomPreAlarm(
        id: UUID,
        title: String,
        at preAlarmTime: Date,
        minutesBefore: Int
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
            let alertTitle = String(localized: "\(title) in \(minutesBefore) min", bundle: bundle)
            let snoozeCountdownTitle = String(localized: "Snoozing — \(title) pre-alarm", bundle: bundle)

            let presentation = makePresentation(
                alertTitle: alertTitle,
                snoozeCountdownTitle: snoozeCountdownTitle
            )

            let attributes = AlarmAttributes<AdhanAlarmMetadata>(
                presentation: presentation,
                metadata: AdhanAlarmMetadata(prayerName: "custom_\(id.uuidString)_prealarm", prayerTime: preAlarmTime),
                tintColor: .orange
            )

            let configuration = AlarmKit.AlarmManager.AlarmConfiguration(
                countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: Self.maxAlertDurationSeconds),
                schedule: .fixed(preAlarmTime),
                attributes: attributes,
                stopIntent: StopAdhanAlarmIntent(alarmID: alarmID.uuidString),
                sound: .default
            )

            _ = try await _manager.schedule(id: alarmID, configuration: configuration)
            let trackingKey = "custom_\(id.uuidString)_prealarm"
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

    /// Cancel all scheduled adhan alarms.
    func cancelAll() {
        #if canImport(AlarmKit)
        if #available(iOS 26, *) {
            do {
                let alarms = try _manager.alarms
                AppLogger.alarm.info("cancelAll: found \(alarms.count) alarms to cancel")
                for alarm in alarms {
                    do {
                        try dismiss(alarm)
                    } catch {
                        AppLogger.alarm.error("cancelAll: failed to dismiss alarm \(alarm.id): \(error.localizedDescription)")
                        #if canImport(FirebaseCrashlytics)
                        Crashlytics.crashlytics().record(error: error, userInfo: ["context": "cancelAll_individual", "alarmId": alarm.id.uuidString])
                        #endif
                    }
                }
            } catch {
                AppLogger.alarm.error("cancelAll: failed to enumerate alarms: \(error.localizedDescription)")
                #if canImport(FirebaseCrashlytics)
                Crashlytics.crashlytics().record(error: error, userInfo: ["context": "cancelAll_enumerate"])
                #endif
            }
        }
        #endif
        scheduledAlarmIDs.removeAll()
    }
}

#if canImport(AlarmKit)
@available(iOS 26, *)
private extension AdhanAlarmManager {
    func makeAlert(title: String, stopText: String) -> AlarmPresentation.Alert {
        let titleResource = LocalizedStringResource(stringLiteral: title)
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(title: titleResource)
        }

        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: stopText),
            textColor: .white,
            systemImageName: "xmark"
        )

        return AlarmPresentation.Alert(
            title: titleResource,
            stopButton: stopButton
        )
    }

    func startObservingAlarmState() {
        guard autoStopObserverTask == nil else { return }

        autoStopObserverTask = Task { [weak self] in
            guard let self else { return }

            if let alarms = try? _manager.alarms {
                await handleAlarmUpdates(alarms)
            }

            for await alarms in _manager.alarmUpdates {
                await handleAlarmUpdates(alarms)
            }
        }
    }

    func handleAlarmUpdates(_ alarms: [AlarmKit.Alarm]) {
        let incomingIDs = Set(alarms.map(\.id))

        for alarmID in autoStopTasks.keys where !incomingIDs.contains(alarmID) {
            cancelAutoStop(for: alarmID)
        }

        Task {
            await AlarmLiveActivityCleanup.endActivitiesWithoutCurrentAlarm(in: alarms)
        }

        for alarm in alarms {
            if alarm.state == .alerting {
                scheduleAutoStopIfNeeded(for: alarm)
            } else {
                cancelAutoStop(for: alarm.id)
            }
        }
    }

    func scheduleAutoStopIfNeeded(for alarm: AlarmKit.Alarm) {
        let alarmID = alarm.id
        guard autoStopTasks[alarmID] == nil else { return }

        let delay = remainingAutoStopDelay(for: alarm)
        autoStopTasks[alarmID] = Task { [weak self] in
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return
                }
            }

            await self?.stopIfStillAlerting(alarmID)
        }
    }

    func stopIfStillAlerting(_ alarmID: UUID) async {
        defer { cancelAutoStop(for: alarmID) }

        do {
            guard let liveAlarm = try _manager.alarms.first(where: { $0.id == alarmID }) else {
                return
            }
            guard liveAlarm.state == .alerting else {
                return
            }

            try _manager.stop(id: alarmID)
            AppLogger.alarm.info("auto-stop: stopped alarm \(alarmID.uuidString, privacy: .public) after 5 minutes")
            Task {
                await AlarmLiveActivityCleanup.endActivities(for: [alarmID])
            }
        } catch {
            AppLogger.alarm.error("auto-stop: failed to stop alarm \(alarmID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().record(error: error, userInfo: ["context": "auto_stop_alarm", "alarmId": alarmID.uuidString])
            #endif
        }
    }

    func cancelAutoStop(for alarmID: UUID) {
        autoStopTasks.removeValue(forKey: alarmID)?.cancel()
    }

    func dismiss(_ alarm: AlarmKit.Alarm) throws {
        switch alarm.state {
        case .alerting:
            try _manager.stop(id: alarm.id)
        case .scheduled, .countdown, .paused:
            try _manager.cancel(id: alarm.id)
        @unknown default:
            try _manager.cancel(id: alarm.id)
        }
        cancelAutoStop(for: alarm.id)
        Task {
            await AlarmLiveActivityCleanup.endActivities(for: [alarm.id])
        }
    }

    func remainingAutoStopDelay(for alarm: AlarmKit.Alarm) -> TimeInterval {
        guard let fireDate = fireDate(for: alarm) else {
            return Self.maxAlertDurationSeconds
        }

        let elapsed = Date().timeIntervalSince(fireDate)
        return max(0, Self.maxAlertDurationSeconds - elapsed)
    }

    func fireDate(for alarm: AlarmKit.Alarm) -> Date? {
        switch alarm.schedule {
        case .fixed(let date):
            return date
        case .relative(let schedule):
            let calendar = Calendar.current
            let now = Date()
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = schedule.time.hour
            components.minute = schedule.time.minute
            components.second = 0

            guard var date = calendar.date(from: components) else {
                return nil
            }

            if date > now {
                date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            }
            return date
        case nil:
            return nil
        @unknown default:
            return nil
        }
    }
}
#endif

enum AlarmScheduleError: LocalizedError {
    case notAuthorized(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized(let msg): return msg
        }
    }
}
