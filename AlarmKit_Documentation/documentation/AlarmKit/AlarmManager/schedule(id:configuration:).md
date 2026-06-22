<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/schedule(id:configuration:)",
  "metadataVersion" : "0.1.0",
  "role" : "Instance Method",
  "symbol" : {
    "kind" : "Instance Method",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC8schedule2id13configurationAA0A0V10Foundation4UUIDV_AC0A13ConfigurationVy_xGtYaKAA0A8MetadataRzlF"
  },
  "title" : "schedule(id:configuration:)"
}
-->

# schedule(id:configuration:)

Schedules a new alarm.

```
func schedule<Metadata>(id: Alarm.ID, configuration: AlarmManager.AlarmConfiguration<Metadata>) async throws -> Alarm where Metadata : AlarmMetadata
```

## Parameters

`id`

The alarm’s identifier.

`configuration`

The configuration for the new alarm.

## Discussion

If scheduling a new alarm is successful, the function returns the [`Alarm`](/documentation/AlarmKit/Alarm) structure.
If you provide a [`countdownDuration`](/documentation/AlarmKit/Alarm/countdownDuration-swift.property), the system shows a countdown UI for the specified
duration before the alarm alerts. If you provide a `schedule`, the alarm alerts
at the scheduled time. If you provide both a `countdownDuration` and
a [`schedule`](/documentation/AlarmKit/Alarm/schedule-swift.property), the system shows a countdown UI before the alarm alerts, possibly
on a repeating schedule. Define the ID to encode it into your intent.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
