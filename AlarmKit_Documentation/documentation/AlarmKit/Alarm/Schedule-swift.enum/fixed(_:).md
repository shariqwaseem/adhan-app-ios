<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/Alarm/Schedule-swift.enum/fixed(_:)",
  "metadataVersion" : "0.1.0",
  "role" : "Case",
  "symbol" : {
    "kind" : "Case",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A0V8ScheduleO5fixedyAE10Foundation4DateVcAEmF"
  },
  "title" : "Alarm.Schedule.fixed(_:)"
}
-->

# Alarm.Schedule.fixed(_:)

A one-shot alarm that fires at a specific time, not a time
relative to the current time zone.

```
case fixed(Date)
```

## Discussion

You can use `fixed` for events where the time won’t
vary based on where the person is located. For example, like
alerting the time of a sports game.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
