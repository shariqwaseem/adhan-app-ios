import SwiftUI
import SwiftData
import AVFoundation

struct AdhanAudioSelectionView: View {
    /// nil = apply to every prayer currently set to Alarm.
    let prayer: PrayerName?
    @Environment(\.modelContext) private var modelContext
    @Environment(AdhanAudioDownloadManager.self) private var downloadManager
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Query private var preferences: [UserPreferences]
    @Query(sort: \CustomAlarm.createdAt) private var customAlarms: [CustomAlarm]

    @State private var player: AVAudioPlayer?
    @State private var playingID: String?

    private var prefs: UserPreferences {
        if let existing = preferences.first { return existing }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    /// nil on the all-prayers screen when alarm prayers use different sounds.
    private var selectedID: String? {
        getAudioSelection()
    }

    var body: some View {
        List {
            Section {
                audioRow(id: "", displayName: "Default")
            } footer: {
                if prayer == nil {
                    Text("Changes the sound for every prayer set to Alarm.")
                }
            }

            Section("Adhan Sounds") {
                ForEach(AdhanAudioCatalog.allFiles) { file in
                    downloadableRow(file: file)
                }
            }
        }
        .navigationTitle("Alarm Sound")
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Default Row

    private func audioRow(id: String, displayName: String) -> some View {
        Button {
            if selectedID == id {
                if playingID == id {
                    stopPlayback()
                } else {
                    playPreview(id: id)
                }
            } else {
                setAudioSelection(id)
                stopPlayback()
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

    // MARK: - Downloadable Row

    private func downloadableRow(file: AdhanAudioFile) -> some View {
        let state = downloadManager.state(for: file.id)
        return Button {
            switch state {
            case .notDownloaded, .failed:
                downloadManager.download(file)
            case .downloading:
                downloadManager.cancelDownload(file)
            case .downloaded:
                if selectedID == file.id {
                    if playingID == file.id {
                        stopPlayback()
                    } else {
                        playPreview(id: file.id)
                    }
                } else {
                    setAudioSelection(file.id)
                    playPreview(id: file.id)
                }
            }
        } label: {
            HStack {
                Text(file.displayName)
                Spacer()
                switch state {
                case .notDownloaded:
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(.secondary)
                case .downloading(let progress):
                    DownloadProgressButton(progress: progress) {
                        downloadManager.cancelDownload(file)
                    }
                case .downloaded:
                    if selectedID == file.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.semibold)
                    }
                case .failed:
                    Image(systemName: "exclamationmark.icloud")
                        .foregroundStyle(.red)
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
              let url = file.playbackURL else {
            playingID = nil
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Preference Get/Set

    private func getAudioSelection() -> String? {
        if let prayer {
            return prefs.alarmAudio(for: prayer)
        }
        return prefs.sharedAlarmAudio
    }

    private func setAudioSelection(_ value: String) {
        let targets = prayer.map { [$0] } ?? prefs.alarmModePrayers
        for target in targets {
            prefs.setAlarmAudio(value, for: target)
        }
        try? modelContext.save()

        Task {
            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: prefs,
                customAlarms: customAlarms,
                reason: .settingsChange
            )
        }
    }
}
