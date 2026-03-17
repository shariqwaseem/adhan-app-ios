import SwiftUI

struct ModeRow: View {
    let mode: PrayerNotificationMode
    let isSelected: Bool
    var isAlarmAuthorized: Bool = true
    var isNotificationAuthorized: Bool = true
    let onTap: () -> Void

    private var isDisabled: Bool {
        if mode == .alarm {
            if !AdhanAlarmManager.isAlarmSupported { return true }
            if !isAlarmAuthorized { return true }
        }
        if mode == .notification && !isNotificationAuthorized { return true }
        return false
    }

    private var disabledReason: String {
        if mode == .notification && !isNotificationAuthorized {
            return "Requires notification permission in Settings"
        }
        if !AdhanAlarmManager.isAlarmSupported {
            return "Requires iOS 26"
        }
        return "Requires alarm permission in Settings"
    }

    var body: some View {
        Button(action: {
            if !isDisabled {
                onTap()
            }
        }) {
            HStack {
                Image(systemName: mode.systemImage)
                    .foregroundStyle(isDisabled ? Color.secondary : (mode == .alarm ? Color.orange : Color.primary))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.localizedName)
                        .font(.body)
                    Text(isDisabled ? disabledReason : mode.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected && !isDisabled {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .tint(.primary)
        .disabled(isDisabled)
    }
}
