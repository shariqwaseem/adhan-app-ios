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
        let bundle = LanguageManager.shared.bundle
        if mode == .notification && !isNotificationAuthorized {
            return String(localized: "Requires notification permission in Settings", bundle: bundle)
        }
        if !AdhanAlarmManager.isAlarmSupported {
            return String(localized: "Requires iOS 26", bundle: bundle)
        }
        return String(localized: "Requires alarm permission in Settings", bundle: bundle)
    }

    private var iconColor: Color {
        if isDisabled { return .secondary }
        switch mode {
        case .alarm: return .orange
        case .notification: return .accentColor
        case .silent: return .primary
        }
    }

    var body: some View {
        Button(action: {
            if !isDisabled {
                onTap()
            }
        }) {
            HStack {
                Image(systemName: mode.systemImage)
                    .foregroundStyle(iconColor)
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
