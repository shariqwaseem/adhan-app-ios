import SwiftUI
import SwiftData
import AVFoundation

struct AdhanAudioSelectionView: View {
    let prayer: PrayerName
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]

    @State private var player: AVAudioPlayer?
    @State private var playingID: String?

    private var prefs: UserPreferences {
        if let existing = preferences.first { return existing }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    private var selectedID: String {
        getAudioSelection()
    }

    var body: some View {
        List {
            Section {
                audioRow(id: "", displayName: "Default")
            }

            Section("Adhan Sounds") {
                ForEach(AdhanAudioCatalog.allFiles) { file in
                    audioRow(id: file.id, displayName: file.displayName)
                }
            }
        }
        .navigationTitle("Alarm Sound")
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Row

    private func audioRow(id: String, displayName: String) -> some View {
        Button {
            if selectedID == id {
                // Tapping already-selected row toggles playback
                if playingID == id {
                    stopPlayback()
                } else {
                    playPreview(id: id)
                }
            } else {
                setAudioSelection(id)
                playPreview(id: id)
            }
        } label: {
            HStack {
                Text(displayName)
                Spacer()
                if selectedID == id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(.primary)
    }

    // MARK: - Playback

    private func playPreview(id: String) {
        stopPlayback()

        guard !id.isEmpty,
              let file = AdhanAudioCatalog.file(forID: id),
              let url = file.bundleURL else {
            playingID = nil
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            playingID = id
        } catch {
            playingID = nil
        }
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        playingID = nil
    }

    // MARK: - Preference Get/Set

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

    private func setAudioSelection(_ value: String) {
        switch prayer {
        case .tahajjud: prefs.tahajjudAlarmAudio = value
        case .fajr: prefs.fajrAlarmAudio = value
        case .dhuhr: prefs.dhuhrAlarmAudio = value
        case .asr: prefs.asrAlarmAudio = value
        case .maghrib: prefs.maghribAlarmAudio = value
        case .isha: prefs.ishaAlarmAudio = value
        }
    }
}
