<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmMetadata",
  "metadataVersion" : "0.1.0",
  "role" : "Protocol",
  "symbol" : {
    "kind" : "Protocol",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A8MetadataP"
  },
  "title" : "AlarmMetadata"
}
-->

# AlarmMetadata

A metadata object that contains information about an alarm.

```
protocol AlarmMetadata : Decodable, Encodable, Hashable, Sendable
```

## Overview

Provide an implementation of this for your own custom content or other information.
The implementation can be empty if you don’t want to provide any additional data for your alarm UI.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
