import Foundation
import Observation

@Observable
@MainActor
final class SyncManager {
    private let store = NSUbiquitousKeyValueStore.default

    // Synced preference keys
    private enum SyncKeys {
        static let calculationMethod = "sync_calculationMethod"
        static let asrMethod = "sync_asrMethod"
        static let highLatitudeRule = "sync_highLatitudeRule"
        static let fajrMode = "sync_fajrNotificationMode"
        static let sunriseMode = "sync_sunriseNotificationMode"
        static let dhuhrMode = "sync_dhuhrNotificationMode"
        static let asrMode = "sync_asrNotificationMode"
        static let maghribMode = "sync_maghribNotificationMode"
        static let ishaMode = "sync_ishaNotificationMode"
        static let ramadanAutoDetect = "sync_ramadanAutoDetect"
        static let ramadanManualOverride = "sync_ramadanManualOverride"
        static let suhoorBuffer = "sync_suhoorBufferMinutes"
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.onExternalChange?()
            }
        }
        store.synchronize()
    }

    // MARK: - Push to iCloud

    func pushPreferences(_ preferences: UserPreferences) {
        store.set(preferences.calculationMethodRawValue, forKey: SyncKeys.calculationMethod)
        store.set(preferences.asrJuristicMethodRawValue, forKey: SyncKeys.asrMethod)
        store.set(preferences.highLatitudeRuleRawValue, forKey: SyncKeys.highLatitudeRule)
        store.set(preferences.fajrNotificationMode, forKey: SyncKeys.fajrMode)
        store.set(preferences.sunriseNotificationMode, forKey: SyncKeys.sunriseMode)
        store.set(preferences.dhuhrNotificationMode, forKey: SyncKeys.dhuhrMode)
        store.set(preferences.asrNotificationMode, forKey: SyncKeys.asrMode)
        store.set(preferences.maghribNotificationMode, forKey: SyncKeys.maghribMode)
        store.set(preferences.ishaNotificationMode, forKey: SyncKeys.ishaMode)
        store.set(preferences.ramadanAutoDetect, forKey: SyncKeys.ramadanAutoDetect)
        store.set(preferences.ramadanManualOverride, forKey: SyncKeys.ramadanManualOverride)
        store.set(preferences.suhoorBufferMinutes, forKey: SyncKeys.suhoorBuffer)
        store.synchronize()
    }

    // MARK: - Pull from iCloud

    func pullPreferences(into preferences: UserPreferences) {
        if let method = store.string(forKey: SyncKeys.calculationMethod), !method.isEmpty {
            preferences.calculationMethodRawValue = method
        }
        if let asr = store.string(forKey: SyncKeys.asrMethod), !asr.isEmpty {
            preferences.asrJuristicMethodRawValue = asr
        }
        if let rule = store.string(forKey: SyncKeys.highLatitudeRule), !rule.isEmpty {
            preferences.highLatitudeRuleRawValue = rule
        }
        if let mode = store.string(forKey: SyncKeys.fajrMode), !mode.isEmpty {
            preferences.fajrNotificationMode = mode
        }
        if let mode = store.string(forKey: SyncKeys.sunriseMode), !mode.isEmpty {
            preferences.sunriseNotificationMode = mode
        }
        if let mode = store.string(forKey: SyncKeys.dhuhrMode), !mode.isEmpty {
            preferences.dhuhrNotificationMode = mode
        }
        if let mode = store.string(forKey: SyncKeys.asrMode), !mode.isEmpty {
            preferences.asrNotificationMode = mode
        }
        if let mode = store.string(forKey: SyncKeys.maghribMode), !mode.isEmpty {
            preferences.maghribNotificationMode = mode
        }
        if let mode = store.string(forKey: SyncKeys.ishaMode), !mode.isEmpty {
            preferences.ishaNotificationMode = mode
        }
        preferences.ramadanAutoDetect = store.bool(forKey: SyncKeys.ramadanAutoDetect)
        preferences.ramadanManualOverride = store.bool(forKey: SyncKeys.ramadanManualOverride)
        let buffer = store.longLong(forKey: SyncKeys.suhoorBuffer)
        if buffer > 0 {
            preferences.suhoorBufferMinutes = Int(buffer)
        }
    }

    // MARK: - External Change Handler

    var onExternalChange: (() -> Void)?
}
