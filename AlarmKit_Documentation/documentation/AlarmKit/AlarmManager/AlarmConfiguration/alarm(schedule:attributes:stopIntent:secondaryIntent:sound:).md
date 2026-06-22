<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/AlarmConfiguration/alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)",
  "metadataVersion" : "0.1.0",
  "role" : "Type Method",
  "symbol" : {
    "kind" : "Type Method",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC0A13ConfigurationV5alarm8schedule10attributes10stopIntent09secondaryI05soundAEy_xGAA0A0V8ScheduleOSg_AA0A10AttributesVyxG10AppIntents012LiveActivityI0_pSgAW0qB005AlertD0V0R5SoundVtFZ"
  },
  "title" : "alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)"
}
-->

# alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)

Creates a configuration that behaves like
a traditional alarm.

```
static func alarm(schedule: Alarm.Schedule? = nil, attributes: AlarmAttributes<Metadata>, stopIntent: (any LiveActivityIntent)? = nil, secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default) -> AlarmManager.AlarmConfiguration<Metadata>
```

## Parameters

`schedule`

The schedule for the alarm.

`attributes`

The attributes to use when presenting the alert.

`stopIntent`

The intent to execute when a person taps the stop button.

`secondaryIntent`

The intent to execute when a person taps the secondary button.

`sound`

The sound to play when the alarm fires.

## Discussion

At the scheduled time, based on the `schedule` parameter you supply,
the alarm alerts.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
