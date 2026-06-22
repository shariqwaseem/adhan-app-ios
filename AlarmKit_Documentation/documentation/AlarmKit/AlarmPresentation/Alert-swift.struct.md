<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A12PresentationV5AlertV"
  },
  "title" : "AlarmPresentation.Alert"
}
-->

# AlarmPresentation.Alert

An object that describes the UI of the alert that appears when an alarm fires.

```
struct Alert
```

## Overview

`Alert` configures the title and buttons in the alarm UI. The system provides a stop button automatically. Use this object to optionally define a secondary button and its behavior. The code snippet below describes how to configure an `Alert` with a secondary button.

```swift
let alert = AlarmPresentation.Alert(title: "Eggs are ready!",
   secondaryButton: AlarmButton(text: "Repeat", textColor: .blue, systemImageName: "repeat"),
   secondaryButtonBehavior: .countdown)
```

## Topics

### Creating an alert

[`init(title:secondaryButton:secondaryButtonBehavior:)`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/init(title:secondaryButton:secondaryButtonBehavior:))

Creates an alert for an alarm, with a system-provided stop control and optionally a second button.

[`title`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/title)

The title of the alert.

### Creating a second button

[`secondaryButton`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/secondaryButton)

The appearance of the secondary button.

[`secondaryButtonBehavior`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/secondaryButtonBehavior-swift.property)

The defined behavior of the second button.

[`AlarmPresentation.Alert.SecondaryButtonBehavior`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/SecondaryButtonBehavior-swift.enum)

Describes the behaviour of the second button.

### Decoding

### Deprecated

[`init(title:stopButton:secondaryButton:secondaryButtonBehavior:)`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/init(title:stopButton:secondaryButton:secondaryButtonBehavior:))

Creates an alert for an alarm.

[`stopButton`](/documentation/AlarmKit/AlarmPresentation/Alert-swift.struct/stopButton)

The appearance of the stop button.



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
