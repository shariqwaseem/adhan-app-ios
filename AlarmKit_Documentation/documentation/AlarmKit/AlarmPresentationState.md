<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmPresentationState",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A17PresentationStateV"
  },
  "title" : "AlarmPresentationState"
}
-->

# AlarmPresentationState

The system managed content state of an alarm Live Activity.

```
struct AlarmPresentationState
```

## Overview

A Live Activity consists of two components: static attributes and dynamic content.
Using a sports game as an example, the static attributes represent the team names,
while the dynamic content represents the current score that updates throughout the game.

For alarms, these components serve distinct purposes:

- **Static attributes**: Your app provides this content through ``doc://com.apple.alarmkit/documentation/AlarmKit/AlarmAttributes``,
  including information such as tint color and button labels that remain constant.
- **Dynamic content**: AlarmKit provides this content through ``doc://com.apple.alarmkit/documentation/AlarmKit/AlarmPresentationState``,
  including system-managed information such as the alarm ``doc://com.apple.alarmkit/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum/Countdown/fireDate`` and current presentation mode.

The system automatically updates the [`AlarmPresentationState`](/documentation/AlarmKit/AlarmPresentationState) as the alarm transitions
between different states, such as [`Alarm.State.countdown`](/documentation/AlarmKit/Alarm/State-swift.enum/countdown), [`Alarm.State.alerting`](/documentation/AlarmKit/Alarm/State-swift.enum/alerting), and [`Alarm.State.paused`](/documentation/AlarmKit/Alarm/State-swift.enum/paused).

## Topics

### Creating an alarm state

[`init(alarmID:mode:)`](/documentation/AlarmKit/AlarmPresentationState/init(alarmID:mode:))

[`alarmID`](/documentation/AlarmKit/AlarmPresentationState/alarmID)

[`mode`](/documentation/AlarmKit/AlarmPresentationState/mode-swift.property)

[`AlarmPresentationState.Mode`](/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum)

### Decoding

  <doc:AlarmPresentationState/init(from:)>



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
