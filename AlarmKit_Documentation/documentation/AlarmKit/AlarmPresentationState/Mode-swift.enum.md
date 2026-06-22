<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum",
  "metadataVersion" : "0.1.0",
  "role" : "Enumeration",
  "symbol" : {
    "kind" : "Enumeration",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A17PresentationStateV4ModeO"
  },
  "title" : "AlarmPresentationState.Mode"
}
-->

# AlarmPresentationState.Mode

A list of all modes the alarm can be in: either alert, countdown, or paused.

```
enum Mode
```

## Overview

This value is sent as part of [`AlarmPresentationState`](/documentation/AlarmKit/AlarmPresentationState)
to the widget extension, so that it can produce the appropriate UI
for the current state of the alarm.

## Topics

### Creating a countdown

[`AlarmPresentationState.Mode.Countdown`](/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum/Countdown)

An object that specifies a countdown is in progress.

[`AlarmPresentationState.Mode.countdown(_:)`](/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum/countdown(_:))

A mode indicating the alarm timer is active.

### Creating an alert

[`AlarmPresentationState.Mode.Alert`](/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum/Alert)

A value that indicates the current state of an alarm.

[`AlarmPresentationState.Mode.alert(_:)`](/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum/alert(_:))

A mode indicating an alarm emits an alert.

### Pausing an alarm

[`AlarmPresentationState.Mode.Paused`](/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum/Paused)

An object that specifies the current state of the alarm has paused.

[`AlarmPresentationState.Mode.paused(_:)`](/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum/paused(_:))

A mode indicating the alarm isn’t active.

### Decoding



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
