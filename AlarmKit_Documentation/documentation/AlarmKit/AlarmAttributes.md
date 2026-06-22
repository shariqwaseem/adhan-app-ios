<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmAttributes",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A10AttributesV"
  },
  "title" : "AlarmAttributes"
}
-->

# AlarmAttributes

An object that contains all information necessary for the alarm UI.

```
struct AlarmAttributes<Metadata> where Metadata : AlarmMetadata
```

## Overview

This struct includes alerting, countdown, and paused states.
You define all the alarm information when creating the attributes.
When archiving the widget, the widget extension selects which state to
display based on the [`AlarmPresentationState`](/documentation/AlarmKit/AlarmPresentationState) provided in the activity
content state payload. The following example defines the attributes for the alarm UI.

```swift
let attributes = AlarmAttributes(
    presentation: presentation,
    metadata: metadata,
    tintColor: Color.white)
```

## Topics

### Creating an alarm attribute

[`init(presentation:metadata:tintColor:)`](/documentation/AlarmKit/AlarmAttributes/init(presentation:metadata:tintColor:))

[`tintColor`](/documentation/AlarmKit/AlarmAttributes/tintColor)

[`presentation`](/documentation/AlarmKit/AlarmAttributes/presentation)

[`metadata`](/documentation/AlarmKit/AlarmAttributes/metadata)

[`AlarmAttributes.ContentState`](/documentation/AlarmKit/AlarmAttributes/ContentState)

### Decoding and encoding

[`init(from:)`](/documentation/AlarmKit/AlarmAttributes/init(from:))

[`encode(to:)`](/documentation/AlarmKit/AlarmAttributes/encode(to:))



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
