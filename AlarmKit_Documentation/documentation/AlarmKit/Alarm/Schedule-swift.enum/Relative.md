<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A0V8ScheduleO8RelativeV"
  },
  "title" : "Alarm.Schedule.Relative"
}
-->

# Alarm.Schedule.Relative

An object that describes when an alarm alerts, relative to the device’s timezone.

```
struct Relative
```

## Topics

### Creating a scheduled alarm

[`init(time:repeats:)`](/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative/init(time:repeats:))

Creates an alarm that fires at a specific time.

[`Alarm.Schedule.Relative.Time`](/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative/Time-swift.struct)

An object that describes the hour and minute at which an alarm alerts.

### Describing an alarm

[`repeats`](/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative/repeats)

The cadence at which the alarm repeats, if any.

[`time`](/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative/time-swift.property)

The hour and minute at which the alarm alerts, relative to the
device’s current timezone.

[`Alarm.Schedule.Relative.Recurrence`](/documentation/AlarmKit/Alarm/Schedule-swift.enum/Relative/Recurrence)

Describes the cadence at which an alarm will repeat, if any.

### Decoding



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
