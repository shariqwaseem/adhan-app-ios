import SwiftUI

struct HomeView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ZStack {
                TimeOfDayBackground(prayerEntries: viewModel.prayerEntries)

                ScrollView {
                    VStack(spacing: 16) {
                        headerSection
                            .glassCard()
                        ramadanSection
                        countdownSection
                            .glassCard()
                        prayerListSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                viewModel.calculateToday()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text(viewModel.cityName)
                    .font(.subheadline.weight(.medium))
            }

            Text(viewModel.hijriDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        Group {
            if let next = viewModel.nextPrayer {
                VStack(spacing: 8) {
                    Text(next.prayer.localizedName)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)

                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        let remaining = next.adjustedTime.timeIntervalSince(context.date)
                        if remaining > 0 {
                            Text(formattedCountdown(remaining))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        } else {
                            Text("Now")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                        }
                    }

                    Text(next.adjustedTime, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Ramadan

    @ViewBuilder
    private var ramadanSection: some View {
        let ramadanService = RamadanDetectionService()
        let fajr = viewModel.prayerEntries.first(where: { $0.prayer == .fajr })
        let maghrib = viewModel.prayerEntries.first(where: { $0.prayer == .maghrib })
        if let fajr, let maghrib,
           let info = ramadanService.ramadanInfo(fajrTime: fajr.adjustedTime, maghribTime: maghrib.adjustedTime) {
            RamadanBanner(ramadanInfo: info)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func formattedCountdown(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
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
        .background(entry.isNext ? Color.accentColor.opacity(0.1) : .clear)
    }
}

#Preview {
    HomeView()
        .environment(PrayerTimesViewModel())
}
