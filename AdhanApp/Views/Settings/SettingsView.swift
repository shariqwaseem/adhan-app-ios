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
    @State private var calculationRescheduleTask: Task<Void, Never>?

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
                    NavigationLink {
                        CalculationMethodSettingsView()
                    } label: {
                        LabeledContent("Method", value: viewModel.calculationSelectionLabel)
                    }

                    @Bindable var vm = viewModel
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
            .onChange(of: viewModel.calculationSettings) { _, _ in
                calculationSettingsChanged()
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
        let calcMethod = viewModel.calculationSelectionLabel
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

    private func calculationSettingsChanged() {
        syncCalculationPreferences()
        viewModel.recalculate()
        calculationRescheduleTask?.cancel()
        calculationRescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
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

        prefs.calculationSettingsData = viewModel.calculationSettingsData
        prefs.calculationMethodRawValue = viewModel.resolvedCalculationConfiguration.logName
        prefs.asrJuristicMethodRawValue = viewModel.asrMethod.rawValue
        prefs.highLatitudeRuleRawValue = viewModel.highLatitudeRule.rawValue
        try? modelContext.save()
    }
}

private struct CalculationMethodSettingsView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                selectionButton(
                    label: autoCalculationLabel,
                    selection: .automatic,
                    dismissAfterSelection: true
                )

                ForEach(CalculationMethodInfo.allCases) { method in
                    selectionButton(
                        label: method.localizedName,
                        selection: .preset(method),
                        dismissAfterSelection: true
                    )
                }

                selectionButton(
                    label: String(localized: "Custom", bundle: LanguageManager.shared.bundle),
                    selection: .custom(viewModel.customCalculationParameters),
                    dismissAfterSelection: false
                )
            }

            if case .custom = viewModel.calculationSelection {
                Section("Custom Settings") {
                    customCalculationControls
                }

                if let fajr = viewModel.prayerEntries.first(where: { $0.prayer == .fajr }),
                   let isha = viewModel.prayerEntries.first(where: { $0.prayer == .isha }) {
                    Section("Today's Preview") {
                        LabeledContent(
                            "Fajr",
                            value: fajr.adjustedTime.formatted(date: .omitted, time: .shortened)
                        )
                        LabeledContent(
                            "Isha",
                            value: isha.adjustedTime.formatted(date: .omitted, time: .shortened)
                        )
                    }
                }

            }
        }
        .navigationTitle("Method")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: viewModel.calculationSelection)
    }

    private var recommendedMethod: CalculationMethodInfo {
        CalculationMethodInfo.recommendedMethod(forCountryCode: viewModel.countryCode)
    }

    private var autoCalculationLabel: String {
        "Auto (\(recommendedMethod.shortDisplayName))"
    }

    @ViewBuilder
    private func selectionButton(
        label: String,
        selection: CalculationSelection,
        dismissAfterSelection: Bool
    ) -> some View {
        let isSelected = isSelectionActive(selection)

        Button {
            if !isSelected {
                switch selection {
                case .custom:
                    viewModel.setCalculationSelection(.custom(viewModel.customCalculationParameters))
                default:
                    viewModel.setCalculationSelection(selection)
                }
            }

            if dismissAfterSelection {
                dismiss()
            }
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func isSelectionActive(_ selection: CalculationSelection) -> Bool {
        switch (viewModel.calculationSelection, selection) {
        case (.automatic, .automatic), (.custom, .custom):
            return true
        case (.preset(let current), .preset(let candidate)):
            return current == candidate
        default:
            return false
        }
    }

    @ViewBuilder
    private var customCalculationControls: some View {
        Stepper(value: fajrAngleBinding, in: 1...30, step: 0.1) {
            LabeledContent("Fajr Angle", value: angleText(viewModel.customCalculationParameters.fajrAngle))
        }

        Picker("Isha Calculation", selection: ishaModeBinding) {
            Text("Angle").tag(CustomIshaMode.angle)
            Text("Minutes after Maghrib").tag(CustomIshaMode.fixedInterval)
        }

        switch viewModel.customCalculationParameters.ishaRule {
        case .angle(let angle):
            Stepper(value: ishaAngleBinding, in: 1...30, step: 0.1) {
                LabeledContent("Isha Angle", value: angleText(angle))
            }
        case .fixedMinutesAfterMaghrib(let minutes):
            Stepper(value: ishaIntervalBinding, in: 1...240, step: 1) {
                LabeledContent("Isha Interval", value: "\(minutes) min")
            }
        }
    }

    private var fajrAngleBinding: Binding<Double> {
        Binding(
            get: { viewModel.customCalculationParameters.fajrAngle },
            set: { value in
                var custom = viewModel.customCalculationParameters
                custom.fajrAngle = roundedAngle(value)
                viewModel.updateCustomCalculationParameters(custom)
            }
        )
    }

    private var ishaModeBinding: Binding<CustomIshaMode> {
        Binding(
            get: {
                switch viewModel.customCalculationParameters.ishaRule {
                case .angle: return .angle
                case .fixedMinutesAfterMaghrib: return .fixedInterval
                }
            },
            set: { mode in
                var custom = viewModel.customCalculationParameters
                switch mode {
                case .angle:
                    custom.ishaRule = .angle(17)
                case .fixedInterval:
                    custom.ishaRule = .fixedMinutesAfterMaghrib(90)
                }
                viewModel.updateCustomCalculationParameters(custom)
            }
        )
    }

    private var ishaAngleBinding: Binding<Double> {
        Binding(
            get: {
                guard case .angle(let angle) = viewModel.customCalculationParameters.ishaRule else { return 17 }
                return angle
            },
            set: { value in
                var custom = viewModel.customCalculationParameters
                custom.ishaRule = .angle(roundedAngle(value))
                viewModel.updateCustomCalculationParameters(custom)
            }
        )
    }

    private var ishaIntervalBinding: Binding<Int> {
        Binding(
            get: {
                guard case .fixedMinutesAfterMaghrib(let minutes) = viewModel.customCalculationParameters.ishaRule else { return 90 }
                return minutes
            },
            set: { value in
                var custom = viewModel.customCalculationParameters
                custom.ishaRule = .fixedMinutesAfterMaghrib(CustomCalculationParameters.clampedInterval(value))
                viewModel.updateCustomCalculationParameters(custom)
            }
        )
    }

    private func roundedAngle(_ value: Double) -> Double {
        CustomCalculationParameters.clampedAngle((value * 10).rounded() / 10)
    }

    private func angleText(_ value: Double) -> String {
        String(format: "%.1f°", value)
    }
}

private enum CustomIshaMode: Hashable {
    case angle
    case fixedInterval
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
