<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/alarmUpdates-swift.property",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Property",
  "symbol" : {
    "kind" : "Instance Property",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC12alarmUpdatesQrvp"
  },
  "title" : "alarmUpdates"
}
-->

# alarmUpdates

An asynchronous sequence that emits events when the set of alarms changes.

```
var alarmUpdates: some AsyncSequence<Array<Alarm>, Never> { get }
```

## Discussion

Use this to receive a notification when an alarm alerts, snoozes, or dismisses.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
