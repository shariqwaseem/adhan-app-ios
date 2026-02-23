import SwiftUI
import SwiftData

struct PrayerDetailView: View {
    let prayer: PrayerName
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    private var prefs: UserPreferences {
        if let existing = preferences.first { return existing }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    private var selectedMode: PrayerNotificationMode {
        get { getMode() }
    }

    var body: some View {
        List {
            deliveryModeSection
            alarmOffsetSection
            preReminderSection
            manualAdjustmentSection
        }
        .navigationTitle(prayer.localizedName)
    }

    // MARK: - Delivery Mode Section

    private var deliveryModeSection: some View {
        Section {
            ForEach(PrayerNotificationMode.allCases) { mode in
                ModeRow(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    onTap: { setMode(mode) }
                )
            }
        } header: {
            Text("Delivery Mode")
        } footer: {
            if selectedMode == .alarm {
                Text("Alarm mode plays the full athan sound and bypasses Silent Mode. Requires Alarm permission.")
            }
        }
    }

    // MARK: - Alarm Offset Section

    @ViewBuilder
    private var alarmOffsetSection: some View {
        if selectedMode == .alarm && prayer != .sunrise {
            Section {
                let offsetLabel = alarmOffsetValue == 0
                    ? "At prayer time"
                    : "\(alarmOffsetValue) min before prayer"
                Stepper(offsetLabel, value: alarmOffsetBinding, in: 0...30, step: 5)
            } header: {
                Text("Alarm Time Offset")
            } footer: {
                Text("Set how many minutes before the prayer time the alarm should ring.")
            }
        }
    }

    // MARK: - Pre-Reminder Section

    @ViewBuilder
    private var preReminderSection: some View {
        if prayer != .sunrise {
            Section("Pre-Reminder") {
                let label = preReminderMinutes > 0 ? "\(preReminderMinutes) minutes before" : "Off"
                Stepper(label, value: preReminderBinding, in: 0...60, step: 5)
            }
        }
    }

    // MARK: - Manual Adjustment Section

    private var manualAdjustmentSection: some View {
        Section("Manual Adjustment") {
            let label = adjustmentMinutes == 0
                ? "No adjustment"
                : "\(adjustmentMinutes > 0 ? "+" : "")\(adjustmentMinutes) min"
            Stepper(label, value: adjustmentBinding, in: -30...30)
        }
    }

    // MARK: - Mode Get/Set

    private func getMode() -> PrayerNotificationMode {
        let raw: String
        switch prayer {
        case .fajr: raw = prefs.fajrNotificationMode
        case .sunrise: raw = prefs.sunriseNotificationMode
        case .dhuhr: raw = prefs.dhuhrNotificationMode
        case .asr: raw = prefs.asrNotificationMode
        case .maghrib: raw = prefs.maghribNotificationMode
        case .isha: raw = prefs.ishaNotificationMode
        }
        return PrayerNotificationMode(rawValue: raw) ?? .notification
    }

    private func setMode(_ newValue: PrayerNotificationMode) {
        switch prayer {
        case .fajr: prefs.fajrNotificationMode = newValue.rawValue
        case .sunrise: prefs.sunriseNotificationMode = newValue.rawValue
        case .dhuhr: prefs.dhuhrNotificationMode = newValue.rawValue
        case .asr: prefs.asrNotificationMode = newValue.rawValue
        case .maghrib: prefs.maghribNotificationMode = newValue.rawValue
        case .isha: prefs.ishaNotificationMode = newValue.rawValue
        }
    }

    // MARK: - Alarm Offset

    private var alarmOffsetValue: Int {
        switch prayer {
        case .fajr: return prefs.fajrAlarmOffset
        case .sunrise: return 0
        case .dhuhr: return prefs.dhuhrAlarmOffset
        case .asr: return prefs.asrAlarmOffset
        case .maghrib: return prefs.maghribAlarmOffset
        case .isha: return prefs.ishaAlarmOffset
        }
    }

    private var alarmOffsetBinding: Binding<Int> {
        Binding(
            get: { alarmOffsetValue },
            set: { newValue in
                switch prayer {
                case .fajr: prefs.fajrAlarmOffset = newValue
                case .sunrise: break
                case .dhuhr: prefs.dhuhrAlarmOffset = newValue
                case .asr: prefs.asrAlarmOffset = newValue
                case .maghrib: prefs.maghribAlarmOffset = newValue
                case .isha: prefs.ishaAlarmOffset = newValue
                }
            }
        )
    }

    // MARK: - Pre-Reminder

    private var preReminderMinutes: Int {
        switch prayer {
        case .fajr: return prefs.fajrPreReminder
        case .sunrise: return 0
        case .dhuhr: return prefs.dhuhrPreReminder
        case .asr: return prefs.asrPreReminder
        case .maghrib: return prefs.maghribPreReminder
        case .isha: return prefs.ishaPreReminder
        }
    }

    private var preReminderBinding: Binding<Int> {
        Binding(
            get: { preReminderMinutes },
            set: { newValue in
                switch prayer {
                case .fajr: prefs.fajrPreReminder = newValue
                case .sunrise: break
                case .dhuhr: prefs.dhuhrPreReminder = newValue
                case .asr: prefs.asrPreReminder = newValue
                case .maghrib: prefs.maghribPreReminder = newValue
                case .isha: prefs.ishaPreReminder = newValue
                }
            }
        )
    }

    // MARK: - Manual Adjustment

    private var adjustmentMinutes: Int {
        switch prayer {
        case .fajr: return prefs.fajrManualAdjustment
        case .sunrise: return prefs.sunriseManualAdjustment
        case .dhuhr: return prefs.dhuhrManualAdjustment
        case .asr: return prefs.asrManualAdjustment
        case .maghrib: return prefs.maghribManualAdjustment
        case .isha: return prefs.ishaManualAdjustment
        }
    }

    private var adjustmentBinding: Binding<Int> {
        Binding(
            get: { adjustmentMinutes },
            set: { newValue in
                switch prayer {
                case .fajr: prefs.fajrManualAdjustment = newValue
                case .sunrise: prefs.sunriseManualAdjustment = newValue
                case .dhuhr: prefs.dhuhrManualAdjustment = newValue
                case .asr: prefs.asrManualAdjustment = newValue
                case .maghrib: prefs.maghribManualAdjustment = newValue
                case .isha: prefs.ishaManualAdjustment = newValue
                }
            }
        )
    }
}

// MARK: - Mode Row (extracted to help type-checker)

private struct ModeRow: View {
    let mode: PrayerNotificationMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: mode.systemImage)
                    .foregroundStyle(mode == .alarm ? .orange : .primary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.body)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(.primary)
    }
}
