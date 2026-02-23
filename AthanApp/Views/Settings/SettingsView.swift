import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    NavigationLink {
                        LocationSettings()
                    } label: {
                        LabeledContent("City", value: locationManager.cityName)
                    }
                }

                Section("Prayer Calculation") {
                    LabeledContent("Method", value: viewModel.calculationMethod.rawValue)
                    LabeledContent("Asr", value: viewModel.asrMethod.rawValue)
                }

                Section("Ramadan") {
                    LabeledContent("Status") {
                        let hijri = HijriDateService()
                        if hijri.isRamadan(on: Date()) {
                            if let day = hijri.ramadanDay(on: Date()) {
                                Text("Day \(day)")
                            }
                        } else {
                            Text("Not Ramadan")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Prayer Engine", value: "Adhan Swift")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environment(PrayerTimesViewModel())
        .environment(LocationManager())
}
