<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmPresentation",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A12PresentationV"
  },
  "title" : "AlarmPresentation"
}
-->

# AlarmPresentation

An object that describes the content required for the alarm UI.

```
struct AlarmPresentation
```

## Overview

The following example shows how to set different views for an alarm using the `AlarmPresentation` model.

```swift
let alert = AlarmPresentation.Alert(
    title: "Eggs are ready!",
    secondaryButton: AlarmButton(text: "Repeat", textColor: .blue, systemImageName: "repeat"),
    secondaryButtonBehavior: .countdown)

let countdown = AlarmPresentation.Countdown(title: "Eggs are cooking")

let paused = AlarmPresentation.Paused(
    title: "Timer paused",
    resumeButton: AlarmButton(text: "Resume", textColor: .blue, systemImageName: "play.circle"))

let presentation = AlarmPresentation(alert: alert, countdown: countdown, paused: paused)
```

## Topics

### Defining the alarm UI

[`init(alert:countdown:paused:)`](/documentation/AlarmKit/AlarmPresentation/init(alert:countdown:paused:))

Configures an alert with an optional countdown and paused state.

[`alert`](/documentation/AlarmKit/AlarmPresentation/alert-swift.property)

The content for the alert mode of the alarm.

[`countdown`](/documentation/AlarmKit/AlarmPresentation/countdown-swift.property)

The content for the snooze or countdown mode of the alarm.

[`paused`](/documentation/AlarmKit/AlarmPresentation/paused-swift.property)

The content for the pause mode of the alarm.

### Describing an alarm state

[`AlarmPresentation.Alert`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct)

An object that describes the UI of the alert that appears when an alarm fires.

[`AlarmPresentation.Countdown`](/documentation/AlarmKit/AlarmPresentation/Countdown-swift.struct)

An object that describes the content required for the countdown UI.

[`AlarmPresentation.Paused`](/documentation/AlarmKit/AlarmPresentation/Paused-swift.struct)

An object that configures the UI for a paused timer state.

### Decoding



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
