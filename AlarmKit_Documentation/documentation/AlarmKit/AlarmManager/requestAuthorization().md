<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/requestAuthorization()",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Method",
  "symbol" : {
    "kind" : "Instance Method",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC20requestAuthorizationAC0E5StateOyYaKF"
  },
  "title" : "requestAuthorization()"
}
-->

# requestAuthorization()

Requests permission to use the alarm system if it hasn’t been requested before.

```
func requestAuthorization() async throws -> AlarmManager.AuthorizationState
```

## Discussion

If a person using your app denies authorization, all attempts to schedule alarms fail.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
