import SwiftUI

struct RamadanBanner: View {
    let ramadanInfo: RamadanInfo

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.yellow)
                Text("Ramadan Day \(ramadanInfo.day)")
                    .font(.headline)
                Image(systemName: "moon.fill")
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Suhoor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ramadanInfo.suhoorTime, style: .time)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }

                Divider()
                    .frame(height: 30)

                VStack(spacing: 4) {
                    Text("Iftar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ramadanInfo.iftarTime, style: .time)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
            }

            if ramadanInfo.isSuhoorCountdown && ramadanInfo.timeUntilSuhoor > 0 {
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    let remaining = ramadanInfo.suhoorTime.timeIntervalSince(context.date)
                    if remaining > 0 {
                        Text("Suhoor in \(formattedTime(remaining))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } else if ramadanInfo.timeUntilIftar > 0 {
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    let remaining = ramadanInfo.iftarTime.timeIntervalSince(context.date)
                    if remaining > 0 {
                        Text("Iftar in \(formattedTime(remaining))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .background(
            .ultraThinMaterial.opacity(0.9),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        let seconds = total % 60
        return "\(minutes)m \(seconds)s"
    }
}
