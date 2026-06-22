<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/pause(id:)",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Method",
  "symbol" : {
    "kind" : "Instance Method",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC5pause2idy10Foundation4UUIDV_tKF"
  },
  "title" : "pause(id:)"
}
-->

# pause(id:)

Pauses the alarm with the specified ID if it’s in the countdown
state.

```
func pause(id: Alarm.ID) throws
```

## Parameters

`id`

The identifier of the alarm to pause.

## Discussion

The function throws otherwise. Sets the alarm to the [`AlarmPresentationState.Mode.paused(_:)`](/documentation/AlarmKit/AlarmPresentationState/Mode-swift.enum/paused(_:)) state.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
