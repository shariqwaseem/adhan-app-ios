import SwiftUI
import SwiftData
import MessageUI

struct SettingsView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPreferences]
    @Query(sort: \CustomAlarm.createdAt) private var customAlarms: [CustomAlarm]
    @State private var showingMailCompose = false
    @State private var showingMailError = false

    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    NavigationLink {
                        LocationSettings()
                    } label: {
                        LabeledContent("City", value: viewModel.cityName.isEmpty ? String(localized: "Not Set", bundle: LanguageManager.shared.bundle) : viewModel.cityName)
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

                Section {
                    LabeledContent("Version", value: appVersion)

                    Button {
                        if MFMailComposeViewController.canSendMail() {
                            showingMailCompose = true
                        } else {
                            showingMailError = true
                        }
                    } label: {
                        Text("Feedback & Bug Report")
                    }
                } header: {
                    Text("About")
                }

                #if DEBUG
                if !UserDefaults.standard.bool(forKey: "FASTLANE_SCREENSHOTS") {
                    Section("Developer") {
                        Button("Fire Test Alarm in 5s") {
                            scheduleTestAlarm()
                        }
                    }
                }
                #endif

                Section {
                } footer: {
                    Text(String(localized: "Made by Shariq Waseem", bundle: LanguageManager.shared.bundle))
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingMailCompose) {
                FeedbackMailView(diagnostics: buildDiagnostics())
            }
            .alert("Cannot Send Email", isPresented: $showingMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please configure a mail account in Settings, or email shariqwaseem41@gmail.com directly.")
            }
            .onChange(of: viewModel.calculationMethod) { _, _ in
                syncCalculationPreferences()
                viewModel.recalculate()
                reschedule()
            }
            .onChange(of: viewModel.asrMethod) { _, _ in
                syncCalculationPreferences()
                viewModel.recalculate()
                reschedule()
            }
            .onChange(of: viewModel.highLatitudeRule) { _, _ in
                syncCalculationPreferences()
                viewModel.recalculate()
                reschedule()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func buildDiagnostics() -> String {
        let device = UIDevice.current
        let calcMethod = viewModel.calculationMethod.localizedName
        let lang = LanguageManager.shared.currentLanguage
        let location = viewModel.cityName.isEmpty ? "Not Set" : viewModel.cityName

        return """
        ---
        App Version: \(appVersion)
        iOS Version: \(device.systemVersion)
        Device: \(device.model)
        Language: \(lang)
        Location: \(location)
        Calculation Method: \(calcMethod)
        ---
        """
    }

    #if DEBUG
    private func scheduleTestAlarm() {
        Task {
            let alarmManager = AdhanAlarmManager()
            await alarmManager.requestAuthorization()
            let fireTime = Date().addingTimeInterval(5)
            try? await alarmManager.scheduleAlarm(for: .fajr, at: fireTime)
        }
    }

    #endif

    private func reschedule() {
        Task {
            await scheduler.rescheduleAll(
                prayerEntries: viewModel.multiDayTimes(),
                preferences: preferences.first,
                customAlarms: customAlarms
            )
        }
    }

    private func syncCalculationPreferences() {
        let prefs: UserPreferences
        if let existing = preferences.first {
            prefs = existing
        } else {
            let new = UserPreferences()
            modelContext.insert(new)
            prefs = new
        }

        prefs.calculationMethodRawValue = viewModel.calculationMethod.rawValue
        prefs.asrJuristicMethodRawValue = viewModel.asrMethod.rawValue
        prefs.highLatitudeRuleRawValue = viewModel.highLatitudeRule.rawValue
        try? modelContext.save()
    }
}

// MARK: - Mail Compose

struct FeedbackMailView: UIViewControllerRepresentable {
    let diagnostics: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(["shariqwaseem41@gmail.com"])
        vc.setSubject("[Adhan App] Feedback")
        vc.setMessageBody("\n\n\(diagnostics)", isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        @MainActor func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environment(PrayerTimesViewModel())
        .environment(LocationManager())
        .environment(NotificationScheduler())
}
