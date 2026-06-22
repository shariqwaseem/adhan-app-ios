<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmPresentation/Countdown-swift.struct",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A12PresentationV9CountdownV"
  },
  "title" : "AlarmPresentation.Countdown"
}
-->

# AlarmPresentation.Countdown

An object that describes the content required for the countdown UI.

```
struct Countdown
```

## Overview

The code
snippet below describes how to configure a countdown UI with
a pause and resume button.

```swift
let countdown = AlarmPresentation.Countdown(title: "Eggs are cooking")
let paused = AlarmPresentation.Paused(
    title: "Timer paused",
    resumeButton: AlarmButton(text: "Resume", textColor: .blue, systemImageName: "play.circle"))
```

## Topics

### Creates a pause button

[`init(title:pauseButton:)`](/documentation/AlarmKit/AlarmPresentation/Countdown-swift.struct/init(title:pauseButton:))

Creates a countdown with an optional pause button.

[`pauseButton`](/documentation/AlarmKit/AlarmPresentation/Countdown-swift.struct/pauseButton)

The pause button for a countdown timer.

[`title`](/documentation/AlarmKit/AlarmPresentation/Countdown-swift.struct/title)

The title of the countdown.

### Decoding



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
