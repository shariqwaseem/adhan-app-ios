<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmPresentation/init(alert:countdown:paused:)",
  "metadataVersion" : "0.1.0",
  "role" : "Initializer",
  "symbol" : {
    "kind" : "Initializer",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A12PresentationV5alert9countdown6pausedA2C5AlertV_AC9CountdownVSgAC6PausedVSgtcfc"
  },
  "title" : "init(alert:countdown:paused:)"
}
-->

# init(alert:countdown:paused:)

Configures an alert with an optional countdown and paused state.

```
init(alert: AlarmPresentation.Alert, countdown: AlarmPresentation.Countdown? = nil, paused: AlarmPresentation.Paused? = nil)
```

## Parameters

`alert`

The required content for the alert mode of the alarm.

`countdown`

An optional parameter with a default `nil` value.
Provide a [`AlarmPresentation.Countdown`](/documentation/AlarmKit/AlarmPresentation/Countdown-swift.struct) object.

`paused`

An optional parameter with a default `nil` value.
Provide a [`AlarmPresentation.Paused`](/documentation/AlarmKit/AlarmPresentation/Paused-swift.struct) object.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
