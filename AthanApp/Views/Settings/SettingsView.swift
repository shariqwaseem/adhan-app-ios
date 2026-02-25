import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Environment(NotificationScheduler.self) private var scheduler
    @Query private var preferences: [UserPreferences]
    @Query(sort: \CustomAlarm.createdAt) private var customAlarms: [CustomAlarm]

    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    NavigationLink {
                        LocationSettings()
                    } label: {
                        LabeledContent("City", value: viewModel.cityName.isEmpty ? "Not Set" : viewModel.cityName)
                    }
                }

                Section("Prayer Calculation") {
                    @Bindable var vm = viewModel
                    Picker("Method", selection: $vm.calculationMethod) {
                        ForEach(CalculationMethodInfo.allCases) { method in
                            Text(method.localizedName).tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Asr Calculation", selection: $vm.asrMethod) {
                        ForEach(AsrJuristicMethod.allCases) { method in
                            Text(method.localizedName).tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("High Latitude", selection: $vm.highLatitudeRule) {
                        ForEach(HighLatitudeRuleOption.allCases) { rule in
                            Text(rule.localizedName).tag(rule)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Display") {
                    Picker("Language", selection: Binding(
                        get: { LanguageManager.shared.currentLanguage },
                        set: { newValue in LanguageManager.shared.currentLanguage = newValue }
                    )) {
                        Text("English").tag("en")
                        Text("العربية").tag("ar")
                        Text("Bahasa Indonesia").tag("id")
                        Text("Türkçe").tag("tr")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: viewModel.calculationMethod) { _, _ in
                viewModel.recalculate()
                reschedule()
            }
            .onChange(of: viewModel.asrMethod) { _, _ in
                viewModel.recalculate()
                reschedule()
            }
            .onChange(of: viewModel.highLatitudeRule) { _, _ in
                viewModel.recalculate()
                reschedule()
            }
        }
    }

    private func reschedule() {
        Task {
            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: preferences.first,
                customAlarms: customAlarms
            )
        }
    }
}

#Preview {
    SettingsView()
        .environment(PrayerTimesViewModel())
        .environment(LocationManager())
        .environment(NotificationScheduler())
}
