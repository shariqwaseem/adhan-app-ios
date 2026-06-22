<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/Alarm/CountdownDuration-swift.struct/postAlert",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Property",
  "symbol" : {
    "kind" : "Instance Property",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A0V17CountdownDurationV9postAlertSdSgvp"
  },
  "title" : "postAlert"
}
-->

# postAlert

The duration applied after the alarm has alerted at least once and
moves back to the countdown state.

```
var postAlert: TimeInterval?
```

## Discussion

For example, this would be the snooze duration for an alarm.  A
timer with a repeat button could set this value to be the same as
`preAlert`, or it could leave the value as `nil`.  If the value is
`nil` we will use the `preAlert` duration for post-alarm countdowns.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
