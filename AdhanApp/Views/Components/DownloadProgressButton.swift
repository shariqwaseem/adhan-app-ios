import SwiftUI

struct DownloadProgressButton: View {
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        Button {
            onCancel()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "stop.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
    }
}
