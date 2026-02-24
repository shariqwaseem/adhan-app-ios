import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Query private var preferences: [UserPreferences]
    @Query(sort: \CustomAlarm.createdAt) private var customAlarms: [CustomAlarm]

    @State private var showingNewAlarm = false

    private var prefs: UserPreferences? { preferences.first }

    var body: some View {
        NavigationStack {
            ZStack {
                TimeOfDayBackground(prayerEntries: viewModel.prayerEntries)

                ScrollView {
                    VStack(spacing: 12) {
                        countdownSection
                        prayerListSection
                        customAlarmsSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            .navigationTitle(viewModel.cityName.isEmpty ? "Adhan" : viewModel.cityName)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewAlarm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewAlarm) {
                CustomAlarmDetailView()
            }
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
                NavigationLink {
                    PrayerDetailView(prayer: entry.prayer)
                } label: {
                    PrayerRow(entry: entry, mode: currentMode(for: entry.prayer))
                }
                .tint(.primary)
                if entry.prayer != .isha {
                    Divider()
                        .padding(.horizontal)
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Custom Alarms

    @ViewBuilder
    private var customAlarmsSection: some View {
        if !customAlarms.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(customAlarms.enumerated()), id: \.element.id) { index, alarm in
                    NavigationLink {
                        CustomAlarmDetailView(existingAlarm: alarm)
                    } label: {
                        CustomAlarmRow(alarm: alarm)
                    }
                    .tint(.primary)
                    if index < customAlarms.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }

    // MARK: - Helpers

    private func currentMode(for prayer: PrayerName) -> PrayerNotificationMode {
        guard let prefs = prefs else { return .notification }
        let raw: String
        switch prayer {
        case .tahajjud: raw = prefs.tahajjudNotificationMode
        case .fajr: raw = prefs.fajrNotificationMode
        case .dhuhr: raw = prefs.dhuhrNotificationMode
        case .asr: raw = prefs.asrNotificationMode
        case .maghrib: raw = prefs.maghribNotificationMode
        case .isha: raw = prefs.ishaNotificationMode
        }
        return PrayerNotificationMode(rawValue: raw) ?? .notification
    }

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

// MARK: - Custom Alarm Row

struct CustomAlarmRow: View {
    let alarm: CustomAlarm

    private var formattedTime: String {
        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(alarm.hour):\(String(format: "%02d", alarm.minute))"
    }

    var body: some View {
        HStack {
            Image(systemName: "alarm.fill")
                .font(.body)
                .foregroundStyle(alarm.isEnabled ? .orange : .secondary)
                .frame(width: 28)

            Text(alarm.title)
                .font(.body.weight(.regular))

            Spacer()

            Image(systemName: alarm.mode.systemImage)
                .font(.caption)
                .foregroundStyle(alarm.mode == .alarm ? .orange : .secondary)

            Text(formattedTime)
                .font(.body)
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .opacity(alarm.isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Prayer Row

struct PrayerRow: View {
    let entry: PrayerTimeEntry
    var mode: PrayerNotificationMode = .notification

    var body: some View {
        HStack {
            Image(systemName: entry.prayer.systemImage)
                .font(.body)
                .foregroundStyle(entry.isNext ? Color.accentColor : .secondary)
                .frame(width: 28)

            Text(entry.prayer.localizedName)
                .font(.body.weight(entry.isNext ? .semibold : .regular))

            Spacer()

            Image(systemName: mode.systemImage)
                .font(.caption)
                .foregroundStyle(mode == .alarm ? .orange : .secondary)

            Text(entry.adjustedTime, style: .time)
                .font(.body.weight(entry.isNext ? .semibold : .regular))
                .monospacedDigit()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

#Preview {
    HomeView()
        .environment(PrayerTimesViewModel())
}
