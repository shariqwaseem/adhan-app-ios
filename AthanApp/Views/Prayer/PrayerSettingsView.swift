import SwiftUI
import SwiftData

struct PrayerSettingsView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Query private var preferences: [UserPreferences]

    private var prefs: UserPreferences? { preferences.first }

    var body: some View {
        NavigationStack {
            List {
                Section("Today's Prayer Times") {
                    ForEach(viewModel.prayerEntries) { entry in
                        NavigationLink {
                            PrayerDetailView(prayer: entry.prayer)
                        } label: {
                            prayerRow(entry)
                        }
                    }
                }

                Section("Calculation Method") {
                    @Bindable var vm = viewModel
                    Picker("Method", selection: $vm.calculationMethod) {
                        ForEach(CalculationMethodInfo.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Asr Calculation", selection: $vm.asrMethod) {
                        ForEach(AsrJuristicMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("High Latitude", selection: $vm.highLatitudeRule) {
                        ForEach(HighLatitudeRuleOption.allCases) { rule in
                            Text(rule.rawValue).tag(rule)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }
            .navigationTitle("Prayer")
            .onChange(of: viewModel.calculationMethod) { _, _ in viewModel.recalculate() }
            .onChange(of: viewModel.asrMethod) { _, _ in viewModel.recalculate() }
            .onChange(of: viewModel.highLatitudeRule) { _, _ in viewModel.recalculate() }
        }
    }

    private func prayerRow(_ entry: PrayerTimeEntry) -> some View {
        HStack {
            Image(systemName: entry.prayer.systemImage)
                .foregroundStyle(entry.isNext ? .primary : .secondary)
                .frame(width: 28)

            Text(entry.prayer.localizedName)
                .font(.body.weight(entry.isNext ? .semibold : .regular))

            Spacer()

            notificationIcon(for: entry.prayer)
                .foregroundStyle(.secondary)
                .font(.caption)

            Text(entry.adjustedTime, style: .time)
                .font(.body)
                .monospacedDigit()
        }
    }

    private func notificationIcon(for prayer: PrayerName) -> some View {
        let mode = currentMode(for: prayer)
        return Image(systemName: mode.systemImage)
            .foregroundStyle(mode == .alarm ? .orange : .secondary)
    }

    private func currentMode(for prayer: PrayerName) -> PrayerNotificationMode {
        guard let prefs = prefs else { return .notification }
        let raw: String
        switch prayer {
        case .fajr: raw = prefs.fajrNotificationMode
        case .sunrise: raw = prefs.sunriseNotificationMode
        case .dhuhr: raw = prefs.dhuhrNotificationMode
        case .asr: raw = prefs.asrNotificationMode
        case .maghrib: raw = prefs.maghribNotificationMode
        case .isha: raw = prefs.ishaNotificationMode
        }
        return PrayerNotificationMode(rawValue: raw) ?? .notification
    }
}

#Preview {
    PrayerSettingsView()
        .environment(PrayerTimesViewModel())
}
