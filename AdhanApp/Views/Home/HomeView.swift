import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
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

    private var activeColorScheme: ColorScheme {
        if UserDefaults.standard.bool(forKey: "FASTLANE_SCREENSHOTS") {
            return .light
        }

        return currentPhase.prefersDarkAppearance ? .dark : .light
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
            .toolbarColorScheme(activeColorScheme, for: .navigationBar, .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    optionsMenu
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
            .onChange(of: viewModel.prayerEntries.map(\.time)) { _, _ in
                scheduler.refreshNextAlarmTime(
                    prayerEntries: viewModel.multiDayTimes().flatMap { $0 },
                    customAlarms: customAlarms,
                    preferences: prefs
                )
            }
        }
        .environment(\.colorScheme, activeColorScheme)
    }

    // MARK: - Countdown

    private var optionsMenu: some View {
        Menu {
            Button {
                showingNewAlarm = true
            } label: {
                Label(String(localized: "Add Alarm", bundle: langBundle), systemImage: "plus")
            }

            Section(String(localized: "Set for all", bundle: langBundle)) {
                Picker(String(localized: "Delivery Mode", bundle: langBundle), selection: allAlarmsModeBinding) {
                    if allAlarmsMode == nil {
                        Text(String(localized: "Mixed", bundle: langBundle))
                            .tag(Optional<PrayerNotificationMode>.none)
                    }

                    ForEach(PrayerNotificationMode.allCases) { mode in
                        Label(mode.localizedName, systemImage: mode.systemImage)
                            .tag(Optional(mode))
                            .disabled(mode == .alarm && !AdhanAlarmManager.isAlarmSupported)
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Label(String(localized: "Options", bundle: langBundle), systemImage: "ellipsis.circle")
        }
    }

    private var allAlarmsModeBinding: Binding<PrayerNotificationMode?> {
        Binding(
            get: { allAlarmsMode },
            set: { newValue in
                guard let newValue else { return }
                setAllAlarmsMode(newValue)
            }
        )
    }

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
                    .onChange(of: remaining <= 0) { _, expired in
                        if expired {
                            viewModel.refreshPrayerState(at: context.date)
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
                    PrayerRow(
                        entry: effectiveEntry,
                        mode: currentMode(for: entry.prayer),
                        hasOffsetAlert: currentAlertTimingSettings(for: entry.prayer).isOffsetAlertEnabled
                    )
                }
                .accessibilityIdentifier("prayer-row-\(entry.prayer.rawValue.lowercased())")
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

    private var allAlarmsMode: PrayerNotificationMode? {
        let modes = PrayerName.allCases.map { currentMode(for: $0) } + customAlarms.map { alarm in
            let mode = alarm.mode
            if mode == .alarm && !AdhanAlarmManager.isAlarmSupported {
                return .notification
            }
            return mode
        }

        guard let firstMode = modes.first else { return nil }
        return modes.allSatisfy { $0 == firstMode } ? firstMode : nil
    }

    private func setAllAlarmsMode(_ mode: PrayerNotificationMode) {
        guard mode != .alarm || AdhanAlarmManager.isAlarmSupported else { return }
        let prefs = writablePreferences()

        withAnimation(.easeInOut(duration: 0.3)) {
            prefs.tahajjudNotificationMode = mode.rawValue
            prefs.fajrNotificationMode = mode.rawValue
            prefs.dhuhrNotificationMode = mode.rawValue
            prefs.asrNotificationMode = mode.rawValue
            prefs.maghribNotificationMode = mode.rawValue
            prefs.ishaNotificationMode = mode.rawValue

            for alarm in customAlarms {
                alarm.mode = mode
            }
        }

        try? modelContext.save()

        Task {
            if mode == .alarm {
                await scheduler.alarmManager.requestAuthorization()
            } else if mode == .notification {
                await scheduler.requestPermission()
            }

            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: prefs,
                customAlarms: customAlarms
            )
        }
    }

    private func writablePreferences() -> UserPreferences {
        if let existing = prefs { return existing }
        let new = UserPreferences()
        modelContext.insert(new)
        return new
    }

    /// The next enabled custom alarm's fire time today (or tomorrow if past).
    private var nextCustomAlarmTime: Date? {
        let now = Date()
        var earliest: Date? = nil
        for alarm in customAlarms where alarm.isEnabled && alarm.mode != .silent {
            guard let time = nextFireTime(for: alarm, after: now) else { continue }
            if earliest == nil || time < earliest! {
                earliest = time
            }
        }
        return earliest
    }

    /// Whether a custom alarm fires before the next prayer.
    private var customAlarmIsNext: Bool {
        guard let customTime = nextCustomAlarmTime,
              let nextScheduledTime = scheduler.nextScheduledAlarmTime else { return false }
        return abs(customTime.timeIntervalSince(nextScheduledTime)) < 1
    }

    /// The ID of the custom alarm that fires next (if it's before next prayer).
    private var nextCustomAlarmID: UUID? {
        guard customAlarmIsNext else { return nil }
        let now = Date()
        var earliestAlarm: CustomAlarm? = nil
        var earliestTime: Date? = nil
        for alarm in customAlarms where alarm.isEnabled && alarm.mode != .silent {
            guard let time = nextFireTime(for: alarm, after: now) else { continue }
            if earliestTime == nil || time < earliestTime! {
                earliestTime = time
                earliestAlarm = alarm
            }
        }
        return earliestAlarm?.id
    }

    private func nextFireTime(for alarm: CustomAlarm, after now: Date) -> Date? {
        let calendar = Calendar.current
        let timing = alarm.alertTimingSettings
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = alarm.hour
        components.minute = alarm.minute
        components.second = 0
        guard let todayTime = calendar.date(from: components) else { return nil }

        var candidates: [Date] = []
        if timing.shouldScheduleMainAlert {
            candidates.append(
                todayTime > now
                    ? todayTime
                    : calendar.date(byAdding: .day, value: 1, to: todayTime) ?? todayTime
            )
        }
        if timing.isOffsetAlertEnabled {
            var offsetTime = timing.offsetFireDate(relativeTo: todayTime)
            if offsetTime <= now,
               let tomorrowTime = calendar.date(byAdding: .day, value: 1, to: todayTime) {
                offsetTime = timing.offsetFireDate(relativeTo: tomorrowTime)
            }
            candidates.append(offsetTime)
        }
        return candidates.filter { $0 > now }.min()
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

    private func currentAlertTimingSettings(for prayer: PrayerName) -> AlertTimingSettings {
        prefs?.alertTimingSettings(for: prayer) ?? AlertTimingSettings()
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
            HomeAlertModeIcon(
                mode: alarm.mode,
                hasOffsetAlert: alarm.alertTimingSettings.isOffsetAlertEnabled
            )

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
    var hasOffsetAlert = false

    var body: some View {
        HStack {
            HomeAlertModeIcon(mode: mode, hasOffsetAlert: hasOffsetAlert)

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

private struct HomeAlertModeIcon: View {
    let mode: PrayerNotificationMode
    let hasOffsetAlert: Bool

    private var color: Color {
        switch mode {
        case .alarm: .orange
        case .notification: .accentColor
        case .silent: .secondary
        }
    }

    var body: some View {
        Image(systemName: mode.systemImage)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(color)
            .overlay(alignment: .topTrailing) {
                if hasOffsetAlert && mode != .silent {
                    ZStack {
                        Circle()
                            .fill(color)
                        Image("OffsetBadge")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundStyle(.black)
                            .blendMode(.destinationOut)
                            .frame(width: 8, height: 5.6)
                    }
                    .compositingGroup()
                    .frame(width: 13, height: 13)
                    .offset(x: mode == .notification ? 8.5 : 12.5, y: -6)
                    .accessibilityHidden(true)
                }
            }
            .frame(width: 36)
            .padding(.trailing, 7)
    }
}

#Preview {
    HomeView()
        .environment(PrayerTimesViewModel())
}
