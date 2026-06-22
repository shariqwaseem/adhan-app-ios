<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager/AlarmConfiguration/timer(duration:attributes:stopIntent:secondaryIntent:sound:)",
  "metadataVersion" : "0.1.0",
  "role" : "Type Method",
  "symbol" : {
    "kind" : "Type Method",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC0A13ConfigurationV5timer8duration10attributes10stopIntent09secondaryI05soundAEy_xGSd_AA0A10AttributesVyxG10AppIntents012LiveActivityI0_pSgAR0pB005AlertD0V0Q5SoundVtFZ"
  },
  "title" : "timer(duration:attributes:stopIntent:secondaryIntent:sound:)"
}
-->

# timer(duration:attributes:stopIntent:secondaryIntent:sound:)

Creates a configuration that behaves like
a traditional timer.

```
static func timer(duration: TimeInterval, attributes: AlarmAttributes<Metadata>, stopIntent: (any LiveActivityIntent)? = nil, secondaryIntent: (any LiveActivityIntent)? = nil, sound: AlertConfiguration.AlertSound = .default) -> AlarmManager.AlarmConfiguration<Metadata>
```

## Parameters

`duration`

The duration of the timer in seconds.

`attributes`

The attributes to use when presenting the alert.

`stopIntent`

The intent to execute when a person stops the timer.

`secondaryIntent`

The intent to execute when a person taps the secondary button.

`sound`

The sound to play when the alarm fires.

## Discussion

The timer starts immediately, runs for `duration` seconds, and then alerts.
If you provide a secondary button with a behavior that indicates that the timer can repeat, the alert has a repeat button.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
