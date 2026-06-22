<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/AlarmConfiguration",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC0A13ConfigurationV"
  },
  "title" : "AlarmManager.AlarmConfiguration"
}
-->

# AlarmManager.AlarmConfiguration

An object that contains all the properties necessary to schedule an alarm.

```
struct AlarmConfiguration<Metadata> where Metadata : AlarmMetadata
```

## Overview

Pass the schedule or countdown and any attributes you define to
the `AlarmConfiguration` for the system to schedule.
You can pass in an optional secondary intent that the system executes when a
person taps a secondary button.
This is only available after first unlock. You can also include custom sounds for your alarm.

The following example configures an alarm with a countdown duration.

```swift
let configuration = AlarmManager.AlarmConfiguration(
    countdownDuration: Alarm.CountdownDuration(preAlert: 10, postAlert: 10),
    schedule: nil,
    attributes: attributes,
    secondaryIntent: repeatIntent,
    alertConfiguration: AlertConfiguration(
        title: "Eggs are ready!",
        body: "Time to eat!",
        sound: .default))
```

## Topics

### Configuring a scheduled alarm

[`alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)`](/documentation/AlarmKit/AlarmManager/AlarmConfiguration/alarm(schedule:attributes:stopIntent:secondaryIntent:sound:))

### Configuring a countdown

[`init(countdownDuration:schedule:attributes:stopIntent:secondaryIntent:sound:)`](/documentation/AlarmKit/AlarmManager/AlarmConfiguration/init(countdownDuration:schedule:attributes:stopIntent:secondaryIntent:sound:))

[`timer(duration:attributes:stopIntent:secondaryIntent:sound:)`](/documentation/AlarmKit/AlarmManager/AlarmConfiguration/timer(duration:attributes:stopIntent:secondaryIntent:sound:))



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
