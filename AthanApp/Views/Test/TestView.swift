import SwiftUI
import SwiftData

struct TestView: View {
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    @State private var resultMessage: String?
    @State private var isFiring = false

    private var prefs: UserPreferences {
        if let existing = preferences.first { return existing }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        fire(mode: .notification)
                    } label: {
                        Label("Test Notification", systemImage: "bell.fill")
                    }
                    .disabled(isFiring)

                    Button {
                        fire(mode: .alarm)
                    } label: {
                        Label("Test Alarm (Default Sound)", systemImage: "alarm.fill")
                    }
                    .disabled(isFiring)
                } header: {
                    Text("Fire in 5 seconds")
                } footer: {
                    Text("Triggers a test notification or alarm that fires 5 seconds from now.")
                }

                Section("Test Alarm with Adhan Audio") {
                    ForEach(PrayerName.allCases) { prayer in
                        let audioID = audioSelection(for: prayer)
                        if !audioID.isEmpty {
                            Button {
                                fireAlarmWithAudio(prayer: prayer, audioID: audioID)
                            } label: {
                                LabeledContent {
                                    Text(AdhanAudioCatalog.displayName(forID: audioID))
                                        .foregroundStyle(.secondary)
                                } label: {
                                    Label(prayer.localizedName, systemImage: "alarm.fill")
                                }
                            }
                            .disabled(isFiring)
                        }
                    }

                    if !hasAnyCustomAudio {
                        Text("No custom adhan audio selected. Set a prayer to Alarm mode and choose an adhan sound to test it here.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }

                if let resultMessage {
                    Section("Result") {
                        Text(resultMessage)
                            .foregroundStyle(resultMessage.starts(with: "Error") ? .red : .green)
                    }
                }
            }
            .navigationTitle("Test")
        }
    }

    // MARK: - Actions

    private func fire(mode: PrayerNotificationMode) {
        isFiring = true
        resultMessage = nil
        Task {
            let result = await scheduler.fireTest(mode: mode)
            resultMessage = result
            isFiring = false
        }
    }

    private func fireAlarmWithAudio(prayer: PrayerName, audioID: String) {
        isFiring = true
        resultMessage = nil
        Task {
            await scheduler.alarmManager.requestAuthorization()
            guard scheduler.alarmManager.isAuthorized else {
                resultMessage = "Alarm not authorized. Check Settings > Apps > Athan."
                isFiring = false
                return
            }
            let testTime = Date().addingTimeInterval(5)
            do {
                let soundPath = AdhanAudioCatalog.bundleRelativePath(forID: audioID)
                try await scheduler.alarmManager.scheduleAlarm(
                    for: prayer,
                    at: testTime,
                    audioFileName: soundPath
                )
                resultMessage = "Alarm with \(AdhanAudioCatalog.displayName(forID: audioID)) scheduled — fires in 5s"
            } catch {
                resultMessage = "Error: \(error.localizedDescription)"
            }
            isFiring = false
        }
    }

    // MARK: - Helpers

    private func audioSelection(for prayer: PrayerName) -> String {
        switch prayer {
        case .tahajjud: return prefs.tahajjudAlarmAudio
        case .fajr: return prefs.fajrAlarmAudio
        case .dhuhr: return prefs.dhuhrAlarmAudio
        case .asr: return prefs.asrAlarmAudio
        case .maghrib: return prefs.maghribAlarmAudio
        case .isha: return prefs.ishaAlarmAudio
        }
    }

    private var hasAnyCustomAudio: Bool {
        PrayerName.allCases.contains { !audioSelection(for: $0).isEmpty }
    }
}
