import SwiftUI
import SwiftData
import UserNotifications

struct OnboardingView: View {
    @Environment(LocationManager.self) private var locationManager
    @Environment(NotificationScheduler.self) private var notificationScheduler
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentStep = 0

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
                subtitle: String(localized: "Allow background location so your prayer times update automatically when you move to a new city. Your location never leaves your device.", bundle: bundle),
                buttonTitle: String(localized: "Allow Background Location", bundle: bundle)
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
                .padding(.horizontal, 40)
                .padding(.bottom, 16)

                Spacer()
                    .frame(height: 36)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    private func handleStepAction() {
        switch steps[currentStep].type {
        case .welcome:
            advanceStep()

        case .location:
            if locationManager.isAuthorized {
                advanceStep()
            } else {
                locationManager.requestWhenInUsePermission()
                waitForAuthorizationChange()
            }

        case .backgroundLocation:
            if locationManager.authorizationStatus == .authorizedAlways {
                advanceStep()
            } else if locationManager.authorizationStatus == .authorizedWhenInUse {
                locationManager.requestAlwaysPermission()
                waitForAuthorizationChange(maxAttempts: 15)
            } else {
                advanceStep()
            }

        case .notifications:
            Task {
                let center = UNUserNotificationCenter.current()
                let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                notificationScheduler.isPermissionGranted = granted ?? false
                advanceStep()
            }

        case .alarms:
            Task {
                await notificationScheduler.alarmManager.requestAuthorization()
                advanceStep()
            }
        }
    }

    private func waitForAuthorizationChange(maxAttempts: Int = 50) {
        Task {
            let startStatus = locationManager.authorizationStatus
            for _ in 0..<maxAttempts {
                try? await Task.sleep(for: .milliseconds(200))
                if locationManager.authorizationStatus != startStatus {
                    break
                }
            }
            advanceStep()
        }
    }

    private func advanceStep() {
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

        let alarmAuthorized = notificationScheduler.alarmManager.isAuthorized

        if alarmAuthorized {
            // Alarm permission granted → all prayers to alarm, system default sound
            let alarm = PrayerNotificationMode.alarm.rawValue
            prefs.fajrNotificationMode = alarm
            prefs.dhuhrNotificationMode = alarm
            prefs.asrNotificationMode = alarm
            prefs.maghribNotificationMode = alarm
            prefs.ishaNotificationMode = alarm
            // Audio stays "" (system default)
        } else if notificationScheduler.isPermissionGranted {
            // Only notification permission → all prayers to notification
            let notif = PrayerNotificationMode.notification.rawValue
            prefs.fajrNotificationMode = notif
            prefs.dhuhrNotificationMode = notif
            prefs.asrNotificationMode = notif
            prefs.maghribNotificationMode = notif
            prefs.ishaNotificationMode = notif
        } else {
            // No permissions granted → all prayers to silent
            let silent = PrayerNotificationMode.silent.rawValue
            prefs.fajrNotificationMode = silent
            prefs.dhuhrNotificationMode = silent
            prefs.asrNotificationMode = silent
            prefs.maghribNotificationMode = silent
            prefs.ishaNotificationMode = silent
        }
        // tahajjud stays silent (the default)

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
        .environment(LocationManager())
        .environment(NotificationScheduler())
}
