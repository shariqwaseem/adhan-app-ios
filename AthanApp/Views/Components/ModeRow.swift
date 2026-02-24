import SwiftUI

struct ModeRow: View {
    let mode: PrayerNotificationMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: mode.systemImage)
                    .foregroundStyle(mode == .alarm ? .orange : .primary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.body)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(.primary)
    }
}
