<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmButton",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A6ButtonV"
  },
  "title" : "AlarmButton"
}
-->

# AlarmButton

A struct that defines the appearance of buttons.

```
struct AlarmButton
```

## Overview

The following example uses `AlarmButton` to define the appearance of the alarm.

```swift
let alert = AlarmPresentation.Alert(
    title: "Eggs are ready!",
    secondaryButton: AlarmButton(text: "Repeat", textColor: .blue, systemImageName: "repeat"),
    secondaryButtonBehavior: .countdown)
```

## Topics

### Creating a button

[`init(text:textColor:systemImageName:)`](/documentation/AlarmKit/AlarmButton/init(text:textColor:systemImageName:))

[`systemImageName`](/documentation/AlarmKit/AlarmButton/systemImageName)

[`textColor`](/documentation/AlarmKit/AlarmButton/textColor)

[`text`](/documentation/AlarmKit/AlarmButton/text)

### Encoding and decoding

[`encode(to:)`](/documentation/AlarmKit/AlarmButton/encode(to:))

[`init(from:)`](/documentation/AlarmKit/AlarmButton/init(from:))



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
