<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/countdown(id:)",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Method",
  "symbol" : {
    "kind" : "Instance Method",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC9countdown2idy10Foundation4UUIDV_tKF"
  },
  "title" : "countdown(id:)"
}
-->

# countdown(id:)

Performs a countdown for the alarm with the specified ID if it’s currently alerting.

```
func countdown(id: Alarm.ID) throws
```

## Parameters

`id`

The identifier of the alarm to perform a countdown for.

## Discussion

The function throws otherwise.
This is identical to the repeat function of a timer, or
the snooze function of an alarm.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
