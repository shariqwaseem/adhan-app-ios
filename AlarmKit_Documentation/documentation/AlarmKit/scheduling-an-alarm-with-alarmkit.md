<!--
{
  "availability" : [
    "Xcode: 26.0.0 -",
    "iOS: 26.0.0 -"
  ],
  "documentType" : "article",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit",
  "metadataVersion" : "0.1.0",
  "role" : "sampleCode",
  "title" : "Scheduling an alarm with AlarmKit"
}
-->

# Scheduling an alarm with AlarmKit

Create prominent alerts at specified dates for your iOS app.

## Overview

An alarm is an alert that presents at a pre-determined time based on a schedule or after a countdown.
It overrides both a device’s focus and silent mode, if necessary.

This sample project uses AlarmKit to create and manage different types of alarms.
In this app people can create and manage:

- **One-time alarms** which alert only once at a specified time in the future.
- **Repeating alarms** which alert with a weekly cadence.
- **Timers** which alert after a countdown, and start immediately.

This project also includes a widget extension for setting up the custom countdown Live Activity associated with an alarm.

> Note: This sample code project is associated with WWDC25 session 230: [Wake up to the AlarmKit API](https://developer.apple.com/wwdc25/230).

## Authorize the app to schedule alarms

This sample prompts people to authorize the app to allow AlarmKit to schedule alarms and create alerts by calling [`requestAuthorization()`](/documentation/AlarmKit/AlarmManager/requestAuthorization()) on [`AlarmManager`](/documentation/AlarmKit/AlarmManager).
Otherwise, when a person adds their first alarm, AlarmKit automatically requests this authorization on behalf of the app, before scheduling the alarm.
If this sample doesn’t get this authorization, then any alarm created by the app isn’t scheduled and subsequently doesn’t alert.

```swift
do {
    let state = try await alarmManager.requestAuthorization()
    return state == .authorized
} catch {
    print("Error occurred while requesting authorization: \(error)")
    return false
}
```

The sample includes the <doc://com.apple.documentation/documentation/BundleResources/Information-Property-List/NSAlarmKitUsageDescription> key in the app’s `Info.plist` with a descriptive string explaining why it schedules alarms.
This string appears in the system prompt when requesting authorization, in this sample the string is:

```
We'll schedule alerts for alarms you create within our app.
```

If the `NSAlarmKitUsageDescription` key is missing or its value is an empty string, apps can’t schedule alarms with AlarmKit.

## Create the alarm schedule

The sample app creates an alarm with either, or both, a countdown duration and a schedule, based on the options a person sets.

[`Alarm.CountdownDuration`](/documentation/AlarmKit/Alarm/CountdownDuration-swift.struct) uses the selected `TimeInterval` for the  pre-alert countdown, which displays the alert when the countdown reaches 0.

[`Alarm.Schedule`](/documentation/AlarmKit/Alarm/Schedule-swift.enum) enables people to set a one-time alarm, or configure a weekly schedule.
For single-occurrence alarms, the [`repeats`](/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative/repeats) property is set to [`Alarm.Schedule.Relative.Recurrence.never`](/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative/Recurrence/never).
For recurring alarms, the `repeats` property is set to [`Alarm.Schedule.Relative.Recurrence.weekly(_:)`](/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative/Recurrence/weekly(_:)) with an associated array `Locale.Weekday`, indicating the days of the week the alarm alerts.

```swift
let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
return .relative(.init(
    time: time,
    repeats: weekdays.isEmpty ? .never : .weekly(Array(weekdays))
))
```

## Configure the alarm’s UI attributes

AlarmKit provides a presentation for each of the three alarm states - [`AlarmPresentation.Alert`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct), [`AlarmPresentation.Countdown`](/documentation/AlarmKit/AlarmPresentation/Countdown-swift.struct), and [`AlarmPresentation.Paused`](/documentation/AlarmKit/AlarmPresentation/Paused-swift.struct).
Because `Countdown` and `Paused` are optional presentations, this sample doesn’t use them if the alarm only has an `Alert` state.

```swift
let alertContent = AlarmPresentation.Alert(title: userInput.localizedLabel,
        stopButton: .stopButton,
        secondaryButton: secondaryButton,
        secondaryButtonBehavior: secondaryButtonBehavior)

guard userInput.countdownDuration != nil else {
    // An alarm without countdown specifies only an alert state.
    return AlarmPresentation(alert: alertContent)
}

// With countdown enabled, provide a presentation for both a countdown and paused state.
let countdownContent = AlarmPresentation.Countdown(title: userInput.localizedLabel,
        pauseButton: .pauseButton)

let pausedContent = AlarmPresentation.Paused(title: "Paused",
        resumeButton: .resumeButton)

return AlarmPresentation(alert: alertContent, countdown: countdownContent, paused: pausedContent)
```

Alongside the [`stopButton`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/stopButton), the sample includes another action button in the alerting UI.
This action depends on [`secondaryButton`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/secondaryButton) and [`secondaryButtonBehavior`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/secondaryButtonBehavior-swift.property).

```swift
var secondaryButtonBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior? {
    switch selectedSecondaryButton {
    case .none: nil
    case .countdown: .countdown
    case .openApp: .custom
    }
}
```

When the `secondaryButtonBehavior` property is set to [`AlarmPresentation.Alert.SecondaryButtonBehavior.countdown`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/SecondaryButtonBehavior-swift.enum/countdown), the secondary button is a `Repeat` action, which re-triggers the alarm after a certain `TimeInterval`, as specified in [`postAlert`](/documentation/AlarmKit/Alarm/CountdownDuration-swift.struct/postAlert).
If the `secondaryButtonBehavior` is set to [`AlarmPresentation.Alert.SecondaryButtonBehavior.custom`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/SecondaryButtonBehavior-swift.enum/custom), the alarm alert displays an `Open` action to launch the app.

```swift
let secondaryButton: AlarmButton? = switch secondaryButtonBehavior {
    case .countdown: .repeatButton
    case .custom: .openAppButton
    default: nil
}
```

> Note: The system forwards the alert presentation to a paired watch (if any) to notify people when an alarm is alerting.

The content for these presentations is wrapped into <doc://com.apple.documentation/documentation/ActivityKit/ActivityAttributes>, along with [`tintColor`](/documentation/AlarmKit/AlarmAttributes/tintColor), and [`metadata`](/documentation/AlarmKit/AlarmAttributes/metadata).
The tint color associates the alarms with the sample app and also differentiates them from other app’s alarms on the person’s device.

```swift
let attributes = AlarmAttributes(presentation: alarmPresentation(with: userInput),
        metadata: CookingData(),
        tintColor: Color.blue)
```

## Schedule the configured alarm

The sample uses a unique identifier to track alarms registered with AlarmKit. The sample manages and updates alarm states, such as [`pause(id:)`](/documentation/AlarmKit/AlarmManager/pause(id:)) and [`cancel(id:)`](/documentation/AlarmKit/AlarmManager/cancel(id:)), using this identifier.

When a person taps the button in the alerting UI, the [`AlarmManager`](/documentation/AlarmKit/AlarmManager) automatically handles stop or countdown functionalities, depending on the button type.

> Tip: You can add additional actions for each button type using <doc://com.apple.documentation/documentation/AppIntents>, which you can configure using ``doc://com.apple.alarmkit/documentation/AlarmKit/AlarmManager/AlarmConfiguration``.

```swift
let id = UUID()
let alarmConfiguration = AlarmConfiguration(countdownDuration: userInput.countdownDuration,
        schedule: userInput.schedule,
        attributes: attributes,
        stopIntent: StopIntent(alarmID: id.uuidString),
        secondaryIntent: secondaryIntent(alarmID: id, userInput: userInput))
```

This sample creates the alarm ID and [`AlarmManager.AlarmConfiguration`](/documentation/AlarmKit/AlarmManager/AlarmConfiguration) and schedules the alarm with [`AlarmManager`](/documentation/AlarmKit/AlarmManager).

```swift
let alarm = try await alarmManager.schedule(id: id, configuration: alarmConfiguration)
```

## Observe state changes on the alarms

At initialization, the `ViewModel` subscribes to alarm events from [`shared`](/documentation/AlarmKit/AlarmManager/shared).
This enables the sample app to have the latest state of an alarm even if the alarm state updated while the sample app isn’t running.

```swift
Task {
    for await incomingAlarms in alarmManager.alarmUpdates {
        updateAlarmState(with: incomingAlarms)
    }
}
```

> Note: An ``doc://com.apple.alarmkit/documentation/AlarmKit/Alarm`` that’s not included in the ``doc://com.apple.alarmkit/documentation/AlarmKit/AlarmManager/alarmUpdates-swift.property`` asynchronous stream is no longer scheduled with AlarmKit.

## Create a Widget Extension for Live Activities

The sample app adds a widget extension target to customize non-alerting presentations in the Dynamic Island, Lock Screen, and StandBy.
The widget extension receives the same [`AlarmAttributes`](/documentation/AlarmKit/AlarmAttributes) structure that you provide to [`shared`](/documentation/AlarmKit/AlarmManager/shared) when scheduling alarms.
It includes the metadata provided in the [Configure the alarm’s UI attributes](#Configure-the-alarms-UI-attributes) section above.

> Important: AlarmKit expects a widget extension if an app supports a countdown presentation.
> Otherwise, the system may unexpectedly dismiss alarms and fail to alert.
> For more information, see <doc://com.apple.documentation/documentation/ActivityKit>.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
