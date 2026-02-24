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
        .animation(.default, value: selectedMode)
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

    // MARK: - Alarm Sound Section

    @ViewBuilder
    private var alarmSoundSection: some View {
        if selectedMode == .alarm {
            Section("Alarm Sound") {
                NavigationLink {
                    AdhanAudioSelectionView(prayer: prayer)
                } label: {
                    LabeledContent("Sound", value: currentAudioDisplayName)
                }
            }
        }
    }

    private var currentAudioDisplayName: String {
        AdhanAudioCatalog.displayName(forID: getAudioSelection())
    }

    // MARK: - Pre-Alarm Section

    private static let preAlarmOptions: [Int] = stride(from: 10, through: 120, by: 5).map { $0 }

    @ViewBuilder
    private var preAlarmSection: some View {
        if (prayer == .fajr || prayer == .tahajjud) && selectedMode != .silent {
            Section {
                Toggle("Pre-Alarm", isOn: Binding(
                    get: { getPreAlarmMinutes() > 0 },
                    set: { enabled in
                        setPreAlarmMinutes(enabled ? 30 : 0)
                    }
                ))

                if getPreAlarmMinutes() > 0 {
                    Picker("Time Before", selection: Binding(
                        get: { getPreAlarmMinutes() },
                        set: { setPreAlarmMinutes($0) }
                    )) {
                        ForEach(Self.preAlarmOptions, id: \.self) { minutes in
                            Text(formattedPreAlarmTime(minutes)).tag(minutes)
                        }
                    }
                }
            } header: {
                Text("Pre-Alarm")
            } footer: {
                Text("Rings before \(prayer.localizedName) using the same delivery mode and sound.")
            }
        }
    }

    private func formattedPreAlarmTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        } else if minutes == 60 {
            return "1 hour"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60) hours"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }

    private func getPreAlarmMinutes() -> Int {
        switch prayer {
        case .fajr: return prefs.fajrPreAlarmMinutes
        case .tahajjud: return prefs.tahajjudPreAlarmMinutes
        default: return 0
        }
    }

    private func setPreAlarmMinutes(_ value: Int) {
        switch prayer {
        case .fajr: prefs.fajrPreAlarmMinutes = value
        case .tahajjud: prefs.tahajjudPreAlarmMinutes = value
        default: break
        }

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
            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: prefs,
                customAlarms: customAlarms
            )
        }
    }
}
