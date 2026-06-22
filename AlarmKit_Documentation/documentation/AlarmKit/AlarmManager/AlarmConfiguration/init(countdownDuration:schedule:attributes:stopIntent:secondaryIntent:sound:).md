<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/AlarmConfiguration/init(countdownDuration:schedule:attributes:stopIntent:secondaryIntent:sound:)",
  "metadataVersion" : "0.1.0",
  "role" : "Initializer",
  "symbol" : {
    "kind" : "Initializer",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC0A13ConfigurationV17countdownDuration8schedule10attributes10stopIntent09secondaryJ05soundAEy_xGAA0A0V09CountdownF0VSg_AN8ScheduleOSgAA0A10AttributesVyxG10AppIntents012LiveActivityJ0_pSgAZ0sB005AlertD0V0T5SoundVtcfc"
  },
  "title" : "init(countdownDuration:schedule:attributes:stopIntent:secondaryIntent:sound:)"
}
-->

# init(countdownDuration:schedule:attributes:stopIntent:secondaryIntent:sound:)

Creates a configuration that behaves like a countdown.

```
init(countdownDuration: Alarm.CountdownDuration? = nil, schedule: Alarm.Schedule? = nil, attributes: AlarmAttributes<Metadata>, stopIntent: (any LiveActivityIntent)? = nil, secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default)
```

## Parameters

`countdownDuration`

The optional countdown duration. When
set to a non-nil value, a countdown shows in the Lock Screen for the specified duration.

`schedule`

The schedule that determines when the alarm alerts.

`attributes`

The attributes of the alarm.

`stopIntent`

The intent to execute when a person stops the countdown.

`secondaryIntent`

The intent to execute when a person taps the secondary button.

`sound`

The sound to play when the alarm fires.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
