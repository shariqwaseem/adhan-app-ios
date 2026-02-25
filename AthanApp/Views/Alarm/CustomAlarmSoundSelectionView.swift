import SwiftUI
import AVFoundation

struct CustomAlarmSoundSelectionView: View {
    @Binding var selectedAudioID: String

    @State private var player: AVAudioPlayer?
    @State private var playingID: String?

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
            if selectedAudioID == id {
                if playingID == id {
                    stopPlayback()
                } else {
                    playPreview(id: id)
                }
            } else {
                selectedAudioID = id
                playPreview(id: id)
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
}
