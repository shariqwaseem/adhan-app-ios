<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/stop(id:)",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Method",
  "symbol" : {
    "kind" : "Instance Method",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC4stop2idy10Foundation4UUIDV_tKF"
  },
  "title" : "stop(id:)"
}
-->

# stop(id:)

Stops the alarm with the specified ID.

```
func stop(id: Alarm.ID) throws
```

## Parameters

`id`

The identifier of the alarm to stop.

## Discussion

If the alarm is a one-shot, meaning
it doesn’t have a repeating schedule, then the system deletes the alarm.
If the alarm repeats then it’s rescheduled to alert or begins
counting down at the next scheduled time.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
