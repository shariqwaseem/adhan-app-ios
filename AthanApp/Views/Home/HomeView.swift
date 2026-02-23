import SwiftUI

struct HomeView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ZStack {
                TimeOfDayBackground(prayerEntries: viewModel.prayerEntries)

                ScrollView {
                    VStack(spacing: 12) {
                        countdownSection
                        prayerListSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            .navigationTitle(viewModel.cityName.isEmpty ? "Adhan" : viewModel.cityName)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                viewModel.calculateToday()
            }
        }
    }

    // MARK: - Countdown

    @ViewBuilder
    private var countdownSection: some View {
        if let next = viewModel.nextPrayer {
            HStack {
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    let remaining = next.adjustedTime.timeIntervalSince(context.date)
                    VStack(alignment: .leading, spacing: 2) {
                        if remaining > 0 {
                            Text(formattedCountdown(remaining))
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("till \(next.prayer.localizedName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(next.prayer.localizedName)
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                            Text("now")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .glassCard()
        }
    }

    // MARK: - Prayer List

    private var prayerListSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.prayerEntries) { entry in
                PrayerRow(entry: entry)
                if entry.prayer != .isha {
                    Divider()
                        .padding(.horizontal)
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Helpers

    private func formattedCountdown(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Prayer Row

struct PrayerRow: View {
    let entry: PrayerTimeEntry

    var body: some View {
        HStack {
            Image(systemName: entry.prayer.systemImage)
                .font(.body)
                .foregroundStyle(entry.isNext ? Color.accentColor : .secondary)
                .frame(width: 28)

            Text(entry.prayer.localizedName)
                .font(.body.weight(entry.isNext ? .semibold : .regular))

            Spacer()

            Text(entry.adjustedTime, style: .time)
                .font(.body.weight(entry.isNext ? .semibold : .regular))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    HomeView()
        .environment(PrayerTimesViewModel())
}
