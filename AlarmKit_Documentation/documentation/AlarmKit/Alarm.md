<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/Alarm",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A0V"
  },
  "title" : "Alarm"
}
-->

# Alarm

An object that describes an alarm that can alert once or on a repeating schedule.

```
struct Alarm
```

## Overview

The following is an example of a 10 second timer:

```swift
let configuration = AlarmManager.AlarmConfiguration(
    countdownDuration: Alarm.CountdownDuration(preAlert: 10, postAlert: 10),
    schedule: nil,
    attributes: attributes,
    secondaryIntent: repeatIntent,
    sound: .default)
```

The following is an example of an alarm that includes a 9 minute snooze option and plays the default sound:

```swift
let configuration = AlarmManager.AlarmConfiguration(
    countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: 9 * 60),
    schedule: .relative(schedule),
    attributes: attributes,
    secondaryIntent: snoozeIntent,
    sound: .default)
```

## Topics

### Defining a countdown duration

[`Alarm.CountdownDuration`](/documentation/AlarmKit/Alarm/CountdownDuration-swift.struct)

[`countdownDuration`](/documentation/AlarmKit/Alarm/countdownDuration-swift.property)

[`id`](/documentation/AlarmKit/Alarm/id)

[`Alarm.State`](/documentation/AlarmKit/Alarm/State-swift.enum)

[`state`](/documentation/AlarmKit/Alarm/state-swift.property)

### Setting an alarm schedule

[`Alarm.Schedule`](/documentation/AlarmKit/Alarm/Schedule-swift.enum)

[`schedule`](/documentation/AlarmKit/Alarm/schedule-swift.property)

### Decoding

  <doc:Alarm/init(from:)>



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
