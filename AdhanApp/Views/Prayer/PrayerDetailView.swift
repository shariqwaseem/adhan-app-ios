import SwiftUI
import SwiftData

struct PrayerDetailView: View {
    let prayer: PrayerName
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Query private var preferences: [UserPreferences]
    @Query(sort: \CustomAlarm.createdAt) private var customAlarms: [CustomAlarm]

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
            alarmSoundSection
            preAlarmSection
        }
        .task {
            await scheduler.checkNotificationPermission()
            scheduler.alarmManager.checkAuthorization()
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
                    isAlarmAuthorized: scheduler.alarmManager.isAuthorized,
                    isNotificationAuthorized: scheduler.isPermissionGranted,
                    onTap: { setMode(mode) }
                )
            }
        } header: {
            Text("Delivery Mode")
        } footer: {
            if !AdhanAlarmManager.isAlarmSupported {
                Text("Alarm mode requires iOS 26 or later. Please update your device to use this feature.")
            } else if !scheduler.alarmManager.isAuthorized || !scheduler.isPermissionGranted {
                let missingBoth = !scheduler.isPermissionGranted && !scheduler.alarmManager.isAuthorized
                let message = missingBoth
                    ? String(localized: "Notification and alarm modes require permission. ", bundle: LanguageManager.shared.bundle)
                    : !scheduler.isPermissionGranted
                        ? String(localized: "Notification mode requires permission. ", bundle: LanguageManager.shared.bundle)
                        : String(localized: "Alarm mode requires permission. ", bundle: LanguageManager.shared.bundle)
                (Text(message) + Text("Open Settings").foregroundColor(.accentColor))
                    .onTapGesture {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
            }
        }
    }

    // MARK: - Alarm Sound Section

    @ViewBuilder
    private var alarmSoundSection: some View {
        if selectedMode == .alarm && getAlertTimingSettings().shouldScheduleMainAlert {
            Section("Alarm Sound") {
                NavigationLink {
                    AdhanAudioSelectionView(prayer: prayer)
                } label: {
                    LabeledContent("Sound", value: currentAudioDisplayName)
                }
                .accessibilityIdentifier("alarm-sound-picker")
            }
        }
    }

    private var currentAudioDisplayName: String {
        AdhanAudioCatalog.displayName(forID: getAudioSelection())
    }

    // MARK: - Offset Alert Section

    @ViewBuilder
    private var preAlarmSection: some View {
        if selectedMode != .silent {
            Section {
                Picker("When", selection: Binding(
                    get: { AlertScheduleSelection(settings: getAlertTimingSettings()) },
                    set: { setAlertSchedule($0) }
                )) {
                    Text("Prayer Time Only").tag(AlertScheduleSelection.mainOnly)
                    Text("Offset Only").tag(AlertScheduleSelection.offsetOnly)
                    Text("Both Times").tag(AlertScheduleSelection.both)
                }

                if getAlertTimingSettings().isOffsetAlertEnabled {
                    Picker("Offset", selection: Binding(
                        get: { getAlertTimingSettings().offsetMinutes },
                        set: { setOffsetMinutes($0) }
                    )) {
                        ForEach(AlertTimingSettings.availableOffsetsMinutes, id: \.self) { offset in
                            Text(formattedOffset(offset)).tag(offset)
                        }
                    }

                    LabeledContent(
                        "Offset Sound",
                        value: String(localized: "Default", bundle: LanguageManager.shared.bundle)
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
            .localizedOffsetDescription(bundle: LanguageManager.shared.bundle)
    }

    private func getAlertTimingSettings() -> AlertTimingSettings {
        prefs.alertTimingSettings(for: prayer)
    }

    private var alertScheduleSummary: String {
        let settings = getAlertTimingSettings()
        let offset = formattedOffset(settings.offsetMinutes)
        let bundle = LanguageManager.shared.bundle
        switch AlertScheduleSelection(settings: settings) {
        case .mainOnly:
            return String(localized: "One alert at prayer time.", bundle: bundle)
        case .offsetOnly:
            return String(localized: "One alert \(offset) prayer time.", bundle: bundle)
        case .both:
            return String(
                localized: "One alert \(offset) prayer time and another at prayer time.",
                bundle: bundle
            )
        }
    }

    private func setAlertSchedule(_ selection: AlertScheduleSelection) {
        setAlertTimingSettings(selection.applying(to: getAlertTimingSettings()))
    }

    private func setOffsetMinutes(_ offset: Int) {
        var settings = getAlertTimingSettings()
        settings.offsetMinutes = offset
        setAlertTimingSettings(settings)
    }

    private func setAlertTimingSettings(_ settings: AlertTimingSettings) {
        prefs.setAlertTimingSettings(settings, for: prayer)

        Task {
            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: prefs,
                customAlarms: customAlarms
            )
        }
    }

    // MARK: - Audio Get/Set

    private func getAudioSelection() -> String {
        switch prayer {
        case .tahajjud: return prefs.tahajjudAlarmAudio
        case .fajr: return prefs.fajrAlarmAudio
        case .dhuhr: return prefs.dhuhrAlarmAudio
        case .asr: return prefs.asrAlarmAudio
        case .maghrib: return prefs.maghribAlarmAudio
        case .isha: return prefs.ishaAlarmAudio
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
        let mode = PrayerNotificationMode(rawValue: raw) ?? .notification
        if mode == .alarm && !AdhanAlarmManager.isAlarmSupported {
            return .notification
        }
        return mode
    }

    private func setMode(_ newValue: PrayerNotificationMode) {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch prayer {
            case .tahajjud: prefs.tahajjudNotificationMode = newValue.rawValue
            case .fajr: prefs.fajrNotificationMode = newValue.rawValue
            case .dhuhr: prefs.dhuhrNotificationMode = newValue.rawValue
            case .asr: prefs.asrNotificationMode = newValue.rawValue
            case .maghrib: prefs.maghribNotificationMode = newValue.rawValue
            case .isha: prefs.ishaNotificationMode = newValue.rawValue
            }
        }

        Task {
            if newValue == .alarm {
                await scheduler.alarmManager.requestAuthorization()
            } else if newValue == .notification {
                await scheduler.requestPermission()
            }
            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: prefs,
                customAlarms: customAlarms
            )
        }
    }
}
