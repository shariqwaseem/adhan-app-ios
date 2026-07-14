import SwiftUI
import SwiftData
import UserNotifications

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

        if AdhanAlarmManager.isAlarmSupported {
            result.append(OnboardingStep(
                type: .alarms,
                icon: "alarm.waves.left.and.right.fill",
                iconColor: .green,
                title: String(localized: "Full Adhan Alarms", bundle: bundle),
                subtitle: String(localized: "This app supports full-length alarms and adhan sounds that play even when your phone is on silent or in Focus mode.", bundle: bundle),
                buttonTitle: String(localized: "Allow Alarms", bundle: bundle)
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

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 32)

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

        // New installs use standard notifications regardless of AlarmKit authorization.
        // Tahajjud stays silent via UserPreferences' default value.
        let notification = PrayerNotificationMode.notification.rawValue
        prefs.fajrNotificationMode = notification
        prefs.dhuhrNotificationMode = notification
        prefs.asrNotificationMode = notification
        prefs.maghribNotificationMode = notification
        prefs.ishaNotificationMode = notification

        modelContext.insert(prefs)
    }
}

private enum OnboardingStepType {
    case welcome, location, backgroundLocation, notifications, alarms
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
