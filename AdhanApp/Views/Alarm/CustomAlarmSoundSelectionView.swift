import SwiftUI
import AVFoundation

struct CustomAlarmSoundSelectionView: View {
    @Binding var selectedAudioID: String
    @Environment(AdhanAudioDownloadManager.self) private var downloadManager

    @State private var player: AVAudioPlayer?
    @State private var playingID: String?

    var body: some View {
        List {
            Section {
                audioRow(id: "", displayName: "Default")
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
            if selectedAudioID == id {
                if playingID == id {
                    stopPlayback()
                } else {
                    playPreview(id: id)
                }
            } else {
                selectedAudioID = id
                stopPlayback()
            }
        } label: {
            HStack {
                Text(displayName)
                Spacer()
                if selectedAudioID == id {
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
                if selectedAudioID == file.id {
                    if playingID == file.id {
                        stopPlayback()
                    } else {
                        playPreview(id: file.id)
                    }
                } else {
                    selectedAudioID = file.id
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
                    if selectedAudioID == file.id {
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
}
