import SwiftUI

struct ModeRow: View {
    let mode: PrayerNotificationMode
    let isSelected: Bool
    let onTap: () -> Void

    private var isAlarmUnavailable: Bool {
        mode == .alarm && !AthanAlarmManager.isAlarmSupported
    }

    var body: some View {
        Button(action: {
            if !isAlarmUnavailable {
                onTap()
            }
        }) {
            HStack {
                Image(systemName: mode.systemImage)
                    .foregroundStyle(isAlarmUnavailable ? Color.secondary : (mode == .alarm ? Color.orange : Color.primary))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.localizedName)
                        .font(.body)
                    Text(isAlarmUnavailable ? "Requires iOS 26" : mode.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected && !isAlarmUnavailable {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(.primary)
        .disabled(isAlarmUnavailable)
    }
}
