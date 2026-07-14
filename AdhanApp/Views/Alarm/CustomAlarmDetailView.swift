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
    @State private var selectedMode: PrayerNotificationMode = .notification
    @State private var selectedAudio: String = ""
    @State private var isEnabled: Bool = true
    @State private var alertTimingSettings = AlertTimingSettings()

    private var isNew: Bool { existingAlarm == nil }
    private var isNotificationMode: Bool { selectedMode == .notification }
    private var langBundle: Bundle { LanguageManager.shared.bundle }

    @ViewBuilder
    private var formContent: some View {
        Form {
            titleSection
            timeSection
            deliveryModeSection
            alarmSoundSection
            preAlarmSection
            if !isNew {
                deleteSection
            }
        }
        .navigationTitle(isNew
            ? (isNotificationMode ? "New Notification" : "New Alarm")
            : (isNotificationMode ? "Edit Notification" : "Edit Alarm"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: selectedMode)
        .task {
            await scheduler.checkNotificationPermission()
            scheduler.alarmManager.checkAuthorization()
        }
        .onAppear { loadFromExisting() }
    }

    var body: some View {
        if isNew {
            NavigationStack {
                formContent
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
            formContent
                .onChange(of: title) { _, _ in syncToExisting() }
                .onChange(of: selectedTime) { _, _ in syncToExisting() }
                .onChange(of: selectedMode) { _, _ in syncToExisting() }
                .onChange(of: selectedAudio) { _, _ in syncToExisting() }
                .onChange(of: isEnabled) { _, _ in syncToExisting() }
                .onChange(of: alertTimingSettings) { _, _ in syncToExisting() }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section("Name") {
            TextField(isNotificationMode ? "Notification name" : "Alarm name", text: $title)
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
            let modes = isNew ? PrayerNotificationMode.allCases.filter { $0 != .silent } : PrayerNotificationMode.allCases
            ForEach(modes) { mode in
                ModeRow(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    isAlarmAuthorized: scheduler.alarmManager.isAuthorized,
                    isNotificationAuthorized: scheduler.isPermissionGranted,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedMode = mode
                        }
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
        } footer: {
            if !scheduler.alarmManager.isAuthorized || !scheduler.isPermissionGranted {
                let missingBoth = !scheduler.isPermissionGranted && !scheduler.alarmManager.isAuthorized
                let bundle = LanguageManager.shared.bundle
                let message = missingBoth
                    ? String(localized: "Notification and alarm modes require permission. ", bundle: bundle)
                    : !scheduler.isPermissionGranted
                        ? String(localized: "Notification mode requires permission. ", bundle: bundle)
                        : String(localized: "Alarm mode requires permission. ", bundle: bundle)
                (Text(message) + Text("Open Settings").foregroundColor(.accentColor))
                    .onTapGesture {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var alarmSoundSection: some View {
        if selectedMode == .alarm && alertTimingSettings.shouldScheduleMainAlert {
            Section("Alarm Sound") {
                NavigationLink {
                    CustomAlarmSoundSelectionView(selectedAudioID: $selectedAudio)
                } label: {
                    LabeledContent("Sound", value: AdhanAudioCatalog.displayName(forID: selectedAudio))
                }
            }
        }
    }

    @ViewBuilder
    private var preAlarmSection: some View {
        if selectedMode != .silent {
            Section {
                Picker("When", selection: Binding(
                    get: { AlertScheduleSelection(settings: alertTimingSettings) },
                    set: { alertTimingSettings = $0.applying(to: alertTimingSettings) }
                )) {
                    Text("Set Time Only").tag(AlertScheduleSelection.mainOnly)
                    Text("Offset Only").tag(AlertScheduleSelection.offsetOnly)
                    Text("Both Times").tag(AlertScheduleSelection.both)
                }

                if alertTimingSettings.isOffsetAlertEnabled {
                    Picker("Offset", selection: $alertTimingSettings.offsetMinutes) {
                        ForEach(AlertTimingSettings.availableOffsetsMinutes, id: \.self) { offset in
                            Text(formattedOffset(offset)).tag(offset)
                        }
                    }

                    LabeledContent(
                        "Offset Sound",
                        value: String(localized: "Default", bundle: langBundle)
                    )
                }
            } header: {
                Text("Alerts")
            } footer: {
                Text(alertScheduleSummary)
            }
        }
    }

    private func formattedOffset(_ offset: Int) -> String {
        AlertTimingSettings(offsetMinutes: offset)
            .localizedOffsetDescription(bundle: langBundle)
    }

    private var alertScheduleSummary: String {
        let offset = formattedOffset(alertTimingSettings.offsetMinutes)
        switch AlertScheduleSelection(settings: alertTimingSettings) {
        case .mainOnly:
            return String(localized: "One alert at the set time.", bundle: langBundle)
        case .offsetOnly:
            return String(localized: "One alert \(offset) the set time.", bundle: langBundle)
        case .both:
            return String(
                localized: "One alert \(offset) the set time and another at the set time.",
                bundle: langBundle
            )
        }
    }

    private var deleteSection: some View {
        Section {
            Button(isNotificationMode ? "Delete Notification" : "Delete Alarm", role: .destructive) {
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
        alertTimingSettings = alarm.alertTimingSettings

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
        alarm.alertTimingSettings = alertTimingSettings
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
            alertTimingSettings: alertTimingSettings
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
