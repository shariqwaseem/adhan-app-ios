import SwiftUI
import SwiftData

struct CustomAlarmDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Query private var preferences: [UserPreferences]
    @Query(sort: \CustomAlarm.createdAt) private var allCustomAlarms: [CustomAlarm]

    /// Nil when creating a new alarm; set when editing an existing one.
    var existingAlarm: CustomAlarm?

    // Local editing state (used for both new and existing)
    @State private var title: String = ""
    @State private var selectedTime: Date = Date()
    @State private var selectedMode: PrayerNotificationMode = .alarm
    @State private var selectedAudio: String = ""
    @State private var isEnabled: Bool = true
    @State private var preAlarmMinutes: Int = 0

    private var isNew: Bool { existingAlarm == nil }

    var body: some View {
        let content = Form {
            titleSection
            timeSection
            deliveryModeSection
            alarmSoundSection
            preAlarmSection
            if !isNew {
                deleteSection
            }
        }
        .animation(.default, value: selectedMode)
        .navigationTitle(isNew ? "New Alarm" : "Edit Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromExisting() }

        if isNew {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { saveNew() }
                                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
            }
        } else {
            content
                .onChange(of: title) { _, _ in syncToExisting() }
                .onChange(of: selectedTime) { _, _ in syncToExisting() }
                .onChange(of: selectedMode) { _, _ in syncToExisting() }
                .onChange(of: selectedAudio) { _, _ in syncToExisting() }
                .onChange(of: isEnabled) { _, _ in syncToExisting() }
                .onChange(of: preAlarmMinutes) { _, _ in syncToExisting() }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section("Name") {
            TextField("Alarm name", text: $title)
        }
    }

    private var timeSection: some View {
        Section("Time") {
            DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
        }
    }

    private var deliveryModeSection: some View {
        Section {
            ForEach(PrayerNotificationMode.allCases) { mode in
                ModeRow(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    onTap: {
                        selectedMode = mode
                        Task {
                            if mode == .alarm {
                                await scheduler.alarmManager.requestAuthorization()
                            } else if mode == .notification {
                                await scheduler.requestPermission()
                            }
                        }
                    }
                )
            }
        } header: {
            Text("Delivery Mode")
        }
    }

    @ViewBuilder
    private var alarmSoundSection: some View {
        if selectedMode == .alarm {
            Section("Alarm Sound") {
                NavigationLink {
                    CustomAlarmSoundSelectionView(selectedAudioID: $selectedAudio)
                } label: {
                    LabeledContent("Sound", value: AdhanAudioCatalog.displayName(forID: selectedAudio))
                }
            }
        }
    }

    private static let preAlarmOptions: [Int] = stride(from: 10, through: 120, by: 5).map { $0 }

    @ViewBuilder
    private var preAlarmSection: some View {
        if selectedMode != .silent {
            Section {
                Toggle("Pre-Alarm", isOn: Binding(
                    get: { preAlarmMinutes > 0 },
                    set: { enabled in
                        preAlarmMinutes = enabled ? 30 : 0
                    }
                ))

                if preAlarmMinutes > 0 {
                    Picker("Time Before", selection: $preAlarmMinutes) {
                        ForEach(Self.preAlarmOptions, id: \.self) { minutes in
                            Text(formattedPreAlarmTime(minutes)).tag(minutes)
                        }
                    }
                    LabeledContent("Sound", value: "Default")
                }
            } header: {
                Text("Pre-Alarm")
            } footer: {
                Text("Rings before this alarm using the same delivery mode with the default sound.")
            }
        }
    }

    private func formattedPreAlarmTime(_ minutes: Int) -> String {
        let bundle = LanguageManager.shared.bundle
        if minutes < 60 {
            return String(localized: "\(minutes) minutes", bundle: bundle)
        } else if minutes == 60 {
            return String(localized: "1 hour", bundle: bundle)
        } else if minutes % 60 == 0 {
            return String(localized: "\(minutes / 60) hours", bundle: bundle)
        } else {
            return String(localized: "\(minutes / 60)h \(minutes % 60)m", bundle: bundle)
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Alarm", role: .destructive) {
                if let alarm = existingAlarm {
                    modelContext.delete(alarm)
                }
                reschedule()
                dismiss()
            }
        }
    }

    // MARK: - Data flow

    private func loadFromExisting() {
        guard let alarm = existingAlarm else { return }
        title = alarm.title
        selectedMode = alarm.mode
        selectedAudio = alarm.alarmAudio
        isEnabled = alarm.isEnabled
        preAlarmMinutes = alarm.preAlarmMinutes

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = alarm.hour
        components.minute = alarm.minute
        selectedTime = Calendar.current.date(from: components) ?? Date()
    }

    private func syncToExisting() {
        guard let alarm = existingAlarm else { return }
        alarm.title = title
        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        alarm.hour = comps.hour ?? 0
        alarm.minute = comps.minute ?? 0
        alarm.mode = selectedMode
        alarm.alarmAudio = selectedAudio
        alarm.isEnabled = isEnabled
        alarm.preAlarmMinutes = preAlarmMinutes
        reschedule()
    }

    private func saveNew() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let alarm = CustomAlarm(
            title: title.trimmingCharacters(in: .whitespaces),
            hour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
            notificationMode: selectedMode,
            alarmAudio: selectedAudio,
            isEnabled: true,
            preAlarmMinutes: preAlarmMinutes
        )
        modelContext.insert(alarm)
        reschedule()
        dismiss()
    }

    private func reschedule() {
        Task {
            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: preferences.first,
                customAlarms: allCustomAlarms
            )
        }
    }
}
