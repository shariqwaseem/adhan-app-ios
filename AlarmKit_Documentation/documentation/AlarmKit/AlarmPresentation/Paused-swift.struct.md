<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmPresentation/Paused-swift.struct",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A12PresentationV6PausedV"
  },
  "title" : "AlarmPresentation.Paused"
}
-->

# AlarmPresentation.Paused

An object that configures the UI for a paused timer state.

```
struct Paused
```

## Overview

This is only applicable to timers that can be paused.
To get back to a countdown state, you must provide a definition for a resume button.
The following code snippet describes how to schedule a timer that can pause and resume.

```swift
let paused = AlarmPresentation.Paused(
    title: "Timer paused",
    resumeButton: AlarmButton(text: "Resume", textColor: .blue, systemImageName: "play.circle"))
```

## Topics

### Creating a resume button

[`init(title:resumeButton:)`](/documentation/AlarmKit/AlarmPresentation/Paused-swift.struct/init(title:resumeButton:))

Creates a pause presentation with a resume button.

[`resumeButton`](/documentation/AlarmKit/AlarmPresentation/Paused-swift.struct/resumeButton)

The appearance of the resume button.

[`title`](/documentation/AlarmKit/AlarmPresentation/Paused-swift.struct/title)

The title of the paused UI.

### Decoding



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
