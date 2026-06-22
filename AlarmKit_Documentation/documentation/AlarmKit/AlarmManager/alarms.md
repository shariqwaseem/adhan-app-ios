<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/alarms",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Property",
  "symbol" : {
    "kind" : "Instance Property",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC6alarmsSayAA0A0VGvp"
  },
  "title" : "alarms"
}
-->

# alarms

Fetches all alarms from the daemon that belong to the current client.

```
var alarms: [Alarm] { get throws }
```

## Discussion

As soon as an alarm fires and stops it’s
deleted from the daemon’s store.  If you want to determine if a
one-shot alarm has fired, persist your alarms in your
own store and compare that with the result of this function call.  If
the array is missing scheduled alarms, then those alarms fired.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
