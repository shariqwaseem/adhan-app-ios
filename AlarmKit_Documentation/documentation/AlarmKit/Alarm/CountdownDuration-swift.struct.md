<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/Alarm/CountdownDuration-swift.struct",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A0V17CountdownDurationV"
  },
  "title" : "Alarm.CountdownDuration"
}
-->

# Alarm.CountdownDuration

An object that defines the durations used in an alarm that has a countdown.

```
struct CountdownDuration
```

## Overview

Provide the countdown duration in seconds.

```swift
Alarm.CountdownDuration(preAlert: 10, postAlert: 10)
```

## Topics

### Creating a countdown duration

[`init(preAlert:postAlert:)`](/documentation/AlarmKit/Alarm/CountdownDuration-swift.struct/init(preAlert:postAlert:))

Creates an instance of a countdown duration.

[`postAlert`](/documentation/AlarmKit/Alarm/CountdownDuration-swift.struct/postAlert)

The duration applied after the alarm has alerted at least once and
moves back to the countdown state.

[`preAlert`](/documentation/AlarmKit/Alarm/CountdownDuration-swift.struct/preAlert)

The duration applied before the alarm fires.

### Decoding



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
