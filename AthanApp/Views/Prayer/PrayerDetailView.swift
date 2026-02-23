import SwiftUI
import SwiftData

struct PrayerDetailView: View {
    let prayer: PrayerName
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(PrayerTimesViewModel.self) private var viewModel
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
        if selectedMode == .alarm {
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


    // MARK: - Mode Get/Set

    private func getMode() -> PrayerNotificationMode {
        let raw: String
        switch prayer {
        case .tahajjud: raw = prefs.tahajjudNotificationMode
        case .fajr: raw = prefs.fajrNotificationMode
        case .dhuhr: raw = prefs.dhuhrNotificationMode
        case .asr: raw = prefs.asrNotificationMode
        case .maghrib: raw = prefs.maghribNotificationMode
        case .isha: raw = prefs.ishaNotificationMode
        }
        return PrayerNotificationMode(rawValue: raw) ?? .notification
    }

    private func setMode(_ newValue: PrayerNotificationMode) {
        switch prayer {
        case .tahajjud: prefs.tahajjudNotificationMode = newValue.rawValue
        case .fajr: prefs.fajrNotificationMode = newValue.rawValue
        case .dhuhr: prefs.dhuhrNotificationMode = newValue.rawValue
        case .asr: prefs.asrNotificationMode = newValue.rawValue
        case .maghrib: prefs.maghribNotificationMode = newValue.rawValue
        case .isha: prefs.ishaNotificationMode = newValue.rawValue
        }

        Task {
            if newValue == .alarm {
                await scheduler.alarmManager.requestAuthorization()
            } else if newValue == .notification {
                await scheduler.requestPermission()
            }
            // Reschedule all notifications/alarms with updated preferences
            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: prefs
            )
        }
    }

    // MARK: - Alarm Offset

    private var alarmOffsetValue: Int {
        switch prayer {
        case .tahajjud: return prefs.tahajjudAlarmOffset
        case .fajr: return prefs.fajrAlarmOffset
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
                case .tahajjud: prefs.tahajjudAlarmOffset = newValue
                case .fajr: prefs.fajrAlarmOffset = newValue
                case .dhuhr: prefs.dhuhrAlarmOffset = newValue
                case .asr: prefs.asrAlarmOffset = newValue
                case .maghrib: prefs.maghribAlarmOffset = newValue
                case .isha: prefs.ishaAlarmOffset = newValue
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
