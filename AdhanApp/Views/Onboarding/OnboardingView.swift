import SwiftUI
import SwiftData
import UserNotifications
import AVFoundation

struct OnboardingView: View {
    @Environment(LocationManager.self) private var locationManager
    @Environment(PrayerTimesViewModel.self) private var prayerTimesViewModel
    @Environment(NotificationScheduler.self) private var notificationScheduler
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentStep = 0
    @State private var pendingPermissionStep: OnboardingStepType?
    @State private var permissionPromptWasPresented = false
    @State private var alertStyle: PrayerNotificationMode = .alarm
    @State private var useAdhanSound = true
    @State private var previewPlayer: AVAudioPlayer?

    /// Mode saved for fajr…isha, based on which permissions were granted and the user's choice.
    private var finalMode: PrayerNotificationMode {
        let notificationsGranted = notificationScheduler.isPermissionGranted
        let alarmsGranted = notificationScheduler.alarmManager.isAuthorized
        if alarmsGranted && (!notificationsGranted || alertStyle == .alarm) {
            return .alarm
        }
        return notificationsGranted ? .notification : .silent
    }

    private var steps: [OnboardingStep] {
        let bundle = LanguageManager.shared.bundle
        var result: [OnboardingStep] = [
            OnboardingStep(
                type: .welcome,
                icon: "moon.stars.fill",
                iconColor: .yellow,
                title: String(localized: "Assalamu Alaikum", bundle: bundle),
                subtitle: String(localized: "Location accurate prayer times, full-length adhan alarms, reminders and Qibla direction — all in one place.", bundle: bundle),
                buttonTitle: String(localized: "Get Started", bundle: bundle)
            ),
            OnboardingStep(
                type: .location,
                icon: "location.fill",
                iconColor: .blue,
                title: String(localized: "Your Location", bundle: bundle),
                subtitle: String(localized: "We need your location to calculate accurate prayer times for your area.", bundle: bundle),
                buttonTitle: String(localized: "Allow Location", bundle: bundle)
            ),
        ]

        if locationManager.isAuthorized {
            result.append(OnboardingStep(
                type: .backgroundLocation,
                icon: "airplane",
                iconColor: .cyan,
                title: String(localized: "Traveling?", bundle: bundle),
                subtitle: String(localized: "Allow location access so Adhan can update prayer times after you travel to a new city. Your location stays on your device.", bundle: bundle),
                buttonTitle: String(localized: "Allow Travel Updates", bundle: bundle)
            ))
        }

        result += [
            OnboardingStep(
                type: .notifications,
                icon: "bell.badge.fill",
                iconColor: .orange,
                title: String(localized: "Never Miss a Prayer", bundle: bundle),
                subtitle: String(localized: "Get notified when it's time to pray so you can stay on track throughout the day.", bundle: bundle),
                buttonTitle: String(localized: "Allow Notifications", bundle: bundle)
            ),
        ]

        result.append(OnboardingStep(
            type: .alarms,
            icon: "alarm.waves.left.and.right.fill",
            iconColor: .green,
            title: String(localized: "Full Adhan Alarms", bundle: bundle),
            subtitle: String(localized: "This app supports full-length alarms and adhan sounds that play even when your phone is on silent or in Focus mode.", bundle: bundle),
            buttonTitle: String(localized: "Allow Alarms", bundle: bundle)
        ))

        if notificationScheduler.isPermissionGranted && notificationScheduler.alarmManager.isAuthorized {
            result.append(OnboardingStep(
                type: .alertStyle,
                icon: "bell.and.waves.left.and.right.fill",
                iconColor: .orange,
                title: String(localized: "How Should We Remind You?", bundle: bundle),
                subtitle: String(localized: "You can change this for each prayer later.", bundle: bundle),
                buttonTitle: String(localized: "Continue", bundle: bundle)
            ))
        }

        if finalMode == .alarm {
            result.append(OnboardingStep(
                type: .alarmSound,
                icon: "speaker.wave.3.fill",
                iconColor: .green,
                title: String(localized: "Alarm Sound", bundle: bundle),
                subtitle: String(localized: "Choose what plays when it's time to pray.", bundle: bundle),
                buttonTitle: String(localized: "Continue", bundle: bundle)
            ))
        }

        return result
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.11, blue: 0.29),
                    Color(red: 0.10, green: 0.16, blue: 0.50)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 80))
                    .foregroundStyle(steps[currentStep].iconColor)
                    .symbolEffect(.pulse, options: .repeating)
                    .frame(height: 120)
                    .id(currentStep)
                    .transition(.scale.combined(with: .opacity))

                Spacer()
                    .frame(height: 40)

                Text(steps[currentStep].title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .id("title-\(currentStep)")
                    .transition(.push(from: .trailing))

                Spacer()
                    .frame(height: 16)

                Text(steps[currentStep].subtitle)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .id("subtitle-\(currentStep)")
                    .transition(.push(from: .trailing))

                choiceOptions
                    .padding(.top, 24)
                    .padding(.horizontal, 40)
                    .id("options-\(currentStep)")
                    .transition(.push(from: .trailing))

                Spacer()

                Button {
                    handleStepAction()
                } label: {
                    Text(steps[currentStep].buttonTitle)
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.29))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: .capsule)
                }
                .disabled(pendingPermissionStep != nil)
                .opacity(pendingPermissionStep == nil ? 1 : 0.7)
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

                Spacer()
                    .frame(height: 36)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .onChange(of: locationManager.authorizationStatus) { _, _ in
            handleLocationAuthorizationResponse()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if pendingPermissionStep != nil, newPhase != .active {
                permissionPromptWasPresented = true
            } else if newPhase == .active {
                handlePermissionPromptReturn()
            }
        }
        .onDisappear {
            stopPreview()
        }
    }

    // MARK: - Choice Steps

    @ViewBuilder
    private var choiceOptions: some View {
        let bundle = LanguageManager.shared.bundle
        switch steps[currentStep].type {
        case .alertStyle:
            VStack(spacing: 12) {
                OnboardingOptionCard(
                    icon: "alarm.fill",
                    title: String(localized: "Alarms", bundle: bundle),
                    isSelected: alertStyle == .alarm
                ) {
                    alertStyle = .alarm
                }
                OnboardingOptionCard(
                    icon: "bell.fill",
                    title: String(localized: "Notifications", bundle: bundle),
                    isSelected: alertStyle == .notification
                ) {
                    alertStyle = .notification
                }
            }

        case .alarmSound:
            VStack(spacing: 12) {
                OnboardingOptionCard(
                    icon: previewPlayer != nil ? "stop.circle.fill" : "play.circle.fill",
                    title: String(localized: "Adhan (Al Maluke)", bundle: bundle),
                    isSelected: useAdhanSound
                ) {
                    if useAdhanSound && previewPlayer != nil {
                        stopPreview()
                    } else {
                        useAdhanSound = true
                        playPreview()
                    }
                }
                OnboardingOptionCard(
                    icon: "alarm",
                    title: String(localized: "Default Alarm", bundle: bundle),
                    isSelected: !useAdhanSound
                ) {
                    useAdhanSound = false
                    stopPreview()
                }
            }

        default:
            EmptyView()
        }
    }

    private func playPreview() {
        stopPreview()
        guard let url = AdhanAudioCatalog.file(forID: AdhanAudioCatalog.bundledID)?.playbackURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            previewPlayer = player
        } catch {
            previewPlayer = nil
        }
    }

    private func stopPreview() {
        guard let previewPlayer else { return }
        previewPlayer.stop()
        self.previewPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handleStepAction() {
        switch steps[currentStep].type {
        case .welcome:
            advanceStep()

        case .location:
            if locationManager.isAuthorized {
                advanceStep(from: .location)
            } else if locationManager.authorizationStatus == .notDetermined {
                beginPermissionRequest(for: .location)
                locationManager.requestWhenInUsePermission()
            } else {
                advanceStep(from: .location)
            }

        case .backgroundLocation:
            if locationManager.authorizationStatus == .authorizedAlways {
                advanceStep(from: .backgroundLocation)
            } else if locationManager.authorizationStatus == .authorizedWhenInUse {
                beginPermissionRequest(for: .backgroundLocation)
                locationManager.requestAlwaysPermission()
                Task {
                    // iOS shows no prompt when location was granted with "Allow Once",
                    // so no status/scene change arrives — advance instead of leaving the button stuck.
                    try? await Task.sleep(for: .seconds(6))
                    if !permissionPromptWasPresented {
                        finishPermissionRequest(for: .backgroundLocation, shouldAdvance: true)
                    }
                }
            } else {
                advanceStep(from: .backgroundLocation)
            }

        case .notifications:
            beginPermissionRequest(for: .notifications)
            Task {
                let center = UNUserNotificationCenter.current()
                let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                notificationScheduler.isPermissionGranted = granted ?? false
                finishPermissionRequest(for: .notifications, shouldAdvance: true)
            }

        case .alarms:
            beginPermissionRequest(for: .alarms)
            Task {
                await notificationScheduler.alarmManager.requestAuthorization()
                finishPermissionRequest(for: .alarms, shouldAdvance: true)
            }

        case .alertStyle:
            advanceStep()

        case .alarmSound:
            stopPreview()
            advanceStep()
        }
    }

    private func beginPermissionRequest(for step: OnboardingStepType) {
        pendingPermissionStep = step
        permissionPromptWasPresented = false
    }

    private func finishPermissionRequest(for step: OnboardingStepType, shouldAdvance: Bool) {
        guard pendingPermissionStep == step else { return }
        pendingPermissionStep = nil
        permissionPromptWasPresented = false
        if shouldAdvance {
            advanceStep(from: step)
        }
    }

    private func handleLocationAuthorizationResponse() {
        guard let pendingPermissionStep else { return }

        switch pendingPermissionStep {
        case .location:
            guard locationManager.authorizationStatus != .notDetermined else { return }
            finishPermissionRequest(for: .location, shouldAdvance: true)

        case .backgroundLocation:
            guard locationManager.authorizationStatus != .authorizedWhenInUse else { return }
            finishPermissionRequest(for: .backgroundLocation, shouldAdvance: true)

        default:
            return
        }
    }

    private func handlePermissionPromptReturn() {
        guard permissionPromptWasPresented,
              let pendingPermissionStep else { return }

        switch pendingPermissionStep {
        case .backgroundLocation:
            finishPermissionRequest(for: .backgroundLocation, shouldAdvance: true)
        default:
            handleLocationAuthorizationResponse()
        }
    }

    private func advanceStep(from expectedStep: OnboardingStepType? = nil) {
        if let expectedStep, steps[currentStep].type != expectedStep {
            return
        }

        if currentStep < steps.count - 1 {
            currentStep += 1
        } else {
            configureDefaultPreferences()
            withAnimation {
                hasCompletedOnboarding = true
            }
        }
    }

    private func configureDefaultPreferences() {
        let prefs = UserPreferences()
        prefs.calculationSettingsData = prayerTimesViewModel.calculationSettingsData
        prefs.calculationMethodRawValue = prayerTimesViewModel.resolvedCalculationConfiguration.logName
        prefs.asrJuristicMethodRawValue = prayerTimesViewModel.asrMethod.rawValue
        prefs.highLatitudeRuleRawValue = prayerTimesViewModel.highLatitudeRule.rawValue

        // Tahajjud stays silent via UserPreferences' default value.
        let mode = finalMode
        prefs.fajrNotificationMode = mode.rawValue
        prefs.dhuhrNotificationMode = mode.rawValue
        prefs.asrNotificationMode = mode.rawValue
        prefs.maghribNotificationMode = mode.rawValue
        prefs.ishaNotificationMode = mode.rawValue

        if mode == .alarm && useAdhanSound {
            for prayer: PrayerName in [.fajr, .dhuhr, .asr, .maghrib, .isha] {
                prefs.setAlarmAudio(AdhanAudioCatalog.bundledID, for: prayer)
            }
        }

        modelContext.insert(prefs)
    }
}

private enum OnboardingStepType {
    case welcome, location, backgroundLocation, notifications, alarms, alertStyle, alarmSound
}

private struct OnboardingOptionCard: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 32)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
            }
            .padding(16)
            .background(.white.opacity(isSelected ? 0.2 : 0.08), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(isSelected ? 0.6 : 0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingStep {
    let type: OnboardingStepType
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let buttonTitle: String
}

#Preview {
    OnboardingView()
        .environment(PrayerTimesViewModel())
        .environment(LocationManager())
        .environment(NotificationScheduler())
}
