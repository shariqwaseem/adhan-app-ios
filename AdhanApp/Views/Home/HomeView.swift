import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Environment(NotificationScheduler.self) private var scheduler
    @Query private var preferences: [UserPreferences]
    @Query(sort: \CustomAlarm.createdAt) private var customAlarms: [CustomAlarm]

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showingNewAlarm = false

    private var prefs: UserPreferences? { preferences.first }
    private var langBundle: Bundle { LanguageManager.shared.bundle }

    private var currentPhase: TimePhase {
        TimePhase.current(for: viewModel.prayerEntries, at: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TimeOfDayBackground(prayerEntries: viewModel.prayerEntries)

                ScrollView {
                    VStack(spacing: 12) {
                        countdownSection
                        VStack {
                            nextAlarmBadge
                        }
                        .animation(.easeInOut(duration: 0.3), value: scheduler.nextScheduledAlarmTime != nil)
                        prayerListSection
                        customAlarmsSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(viewModel.cityName.isEmpty ? "Adhan" : viewModel.cityName)
            .toolbarColorScheme(currentPhase.prefersDarkAppearance ? .dark : .light, for: .navigationBar, .tabBar)
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
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                scheduler.refreshNextAlarmTime(
                    prayerEntries: viewModel.multiDayTimes().flatMap { $0 },
                    customAlarms: customAlarms,
                    preferences: prefs
                )
            }
        }
        .environment(\.colorScheme, currentPhase.prefersDarkAppearance ? .dark : .light)
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
                                .font(.system(size: 52, weight: .bold, design: LanguageManager.shared.isRTL ? .default : .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .foregroundStyle(currentPhase.textColor)
                            Text("till \(next.prayer.localizedName)")
                                .font(.subheadline)
                                .foregroundStyle(currentPhase.textColor.opacity(0.7))
                        } else {
                            Text(next.prayer.localizedName)
                                .font(.system(size: 52, weight: .bold, design: LanguageManager.shared.isRTL ? .default : .rounded))
                                .foregroundStyle(currentPhase.textColor)
                            Text("now")
                                .font(.subheadline)
                                .foregroundStyle(currentPhase.textColor.opacity(0.7))
                        }
                    }
                }
                Spacer()
            }
            .glassCard()
        }
    }

    @ViewBuilder
    private var nextAlarmBadge: some View {
        if let alarmTime = scheduler.nextScheduledAlarmTime {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    let label = scheduler.nextScheduledIsAlarm ? String(localized: "Next alarm", bundle: LanguageManager.shared.bundle) : String(localized: "Next notification", bundle: LanguageManager.shared.bundle)
                    Text(scheduler.nextScheduledName.map { "\(label) — \($0)" } ?? label)
                        .font(.subheadline)
                        .foregroundStyle(currentPhase.textColor.opacity(0.7))
                    Text(alarmTime, style: .time)
                        .font(.system(size: 28, weight: .semibold, design: LanguageManager.shared.isRTL ? .default : .rounded))
                        .monospacedDigit()
                        .foregroundStyle(currentPhase.textColor)
                }
                Spacer()
            }
            .glassCard()
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Prayer List

    private var prayerListSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.prayerEntries) { entry in
                let effectiveEntry = customAlarmIsNext
                    ? PrayerTimeEntry(prayer: entry.prayer, time: entry.time, isNext: false, isCurrent: entry.isCurrent, manualAdjustmentMinutes: entry.manualAdjustmentMinutes)
                    : entry
                NavigationLink {
                    PrayerDetailView(prayer: entry.prayer)
                        .environment(\.colorScheme, systemColorScheme)
                } label: {
                    PrayerRow(entry: effectiveEntry, mode: currentMode(for: entry.prayer))
                }
                .tint(.primary)
                if entry.prayer != .isha {
                    Divider()
                        .padding(.horizontal)
                }
            }
        }
        .compatibleGlassEffect()
    }

    // MARK: - Custom Alarms

    @ViewBuilder
    private var customAlarmsSection: some View {
        if !customAlarms.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(customAlarms.enumerated()), id: \.element.id) { index, alarm in
                    NavigationLink {
                        CustomAlarmDetailView(existingAlarm: alarm)
                            .environment(\.colorScheme, systemColorScheme)
                    } label: {
                        CustomAlarmRow(alarm: alarm, isNext: alarm.id == nextCustomAlarmID)
                    }
                    .tint(.primary)
                    if index < customAlarms.count - 1 {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .compatibleGlassEffect()
        }
    }

    // MARK: - Helpers

    /// The next enabled custom alarm's fire time today (or tomorrow if past).
    private var nextCustomAlarmTime: Date? {
        let now = Date()
        let calendar = Calendar.current
        var earliest: Date? = nil
        for alarm in customAlarms where alarm.isEnabled && alarm.mode != .silent {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            comps.second = 0
            guard var time = calendar.date(from: comps) else { continue }
            if time <= now {
                time = calendar.date(byAdding: .day, value: 1, to: time) ?? time
            }
            if earliest == nil || time < earliest! {
                earliest = time
            }
        }
        return earliest
    }

    /// Whether a custom alarm fires before the next prayer.
    private var customAlarmIsNext: Bool {
        guard let customTime = nextCustomAlarmTime else { return false }
        guard let nextPrayer = viewModel.prayerEntries.first(where: { $0.isNext }) else { return true }
        return customTime < nextPrayer.adjustedTime
    }

    /// The ID of the custom alarm that fires next (if it's before next prayer).
    private var nextCustomAlarmID: UUID? {
        guard customAlarmIsNext else { return nil }
        let now = Date()
        let calendar = Calendar.current
        var earliestAlarm: CustomAlarm? = nil
        var earliestTime: Date? = nil
        for alarm in customAlarms where alarm.isEnabled && alarm.mode != .silent {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            comps.second = 0
            guard var time = calendar.date(from: comps) else { continue }
            if time <= now {
                time = calendar.date(byAdding: .day, value: 1, to: time) ?? time
            }
            if earliestTime == nil || time < earliestTime! {
                earliestTime = time
                earliestAlarm = alarm
            }
        }
        return earliestAlarm?.id
    }

    private func currentMode(for prayer: PrayerName) -> PrayerNotificationMode {
        guard let prefs = prefs else {
            return prayer == .tahajjud ? .silent : .notification
        }
        let raw: String
        switch prayer {
        case .tahajjud: raw = prefs.tahajjudNotificationMode
        case .fajr: raw = prefs.fajrNotificationMode
        case .dhuhr: raw = prefs.dhuhrNotificationMode
        case .asr: raw = prefs.asrNotificationMode
        case .maghrib: raw = prefs.maghribNotificationMode
        case .isha: raw = prefs.ishaNotificationMode
        }
        let mode = PrayerNotificationMode(rawValue: raw) ?? .notification
        if mode == .alarm && !AdhanAlarmManager.isAlarmSupported {
            return .notification
        }
        return mode
    }

    private func formattedCountdown(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if LanguageManager.shared.currentLanguage != "en" {
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%02d:%02d", minutes, seconds)
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }
        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Custom Alarm Row

struct CustomAlarmRow: View {
    let alarm: CustomAlarm
    var isNext: Bool = false

    private var formattedTime: String {
        var components = DateComponents()
        components.hour = alarm.hour
        components.minute = alarm.minute
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.autoupdatingCurrent
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(alarm.hour):\(String(format: "%02d", alarm.minute))"
    }

    var body: some View {
        HStack {
            Image(systemName: alarm.mode.systemImage)
                .font(.body)
                .foregroundStyle(alarm.mode == .alarm ? .orange : alarm.mode == .notification ? Color.accentColor : .secondary)
                .frame(width: 28)

            Text(alarm.title)
                .font(.body.weight(isNext ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            Text(formattedTime)
                .font(.body.weight(isNext ? .semibold : .regular))
                .monospacedDigit()

            Image(systemName: "chevron.forward")
                .font(.system(size: 14, weight: .semibold))
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
            Image(systemName: mode.systemImage)
                .font(.body)
                .foregroundStyle(mode == .alarm ? .orange : mode == .notification ? Color.accentColor : .secondary)
                .frame(width: 28)

            Text(entry.prayer.localizedName)
                .font(.body.weight(entry.isNext ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            Text(entry.adjustedTime, style: .time)
                .font(.body.weight(entry.isNext ? .semibold : .regular))
                .monospacedDigit()

            Image(systemName: "chevron.forward")
                .font(.system(size: 14, weight: .semibold))
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
