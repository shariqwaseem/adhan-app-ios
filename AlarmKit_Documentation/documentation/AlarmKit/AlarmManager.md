<!--
{
  "availability" : [
    "iOS: 26.0.0 -",
    "iPadOS: 26.0.0 -",
    "macCatalyst: 26.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AlarmKit",
  "identifier" : "/documentation/AlarmKit/AlarmManager",
  "metadataVersion" : "0.1.0",
  "role" : "Class",
  "symbol" : {
    "kind" : "Class",
    "modules" : [
      "AlarmKit"
    ],
    "preciseIdentifier" : "s:8AlarmKit0A7ManagerC"
  },
  "title" : "AlarmManager"
}
-->

# AlarmManager

An object that exposes functions to work with alarms: scheduling, snoozing, cancelling.

```
class AlarmManager
```

## Overview

Schedule your alarm alert using `AlarmManager`. The following example calls the `AlarmManager` schedule function by passing in the id and configuration.

```swift
Task {
    let _ = try? await AlarmManager.shared.schedule(id: id, configuration: configuration)
}
```

## Topics

### Creating a shared instance

[`shared`](/documentation/AlarmKit/AlarmManager/shared)

The singleton instance for interacting with the alarm system.

### Updating an alarm

[`AlarmManager.AlarmUpdates`](/documentation/AlarmKit/AlarmManager/AlarmUpdates-swift.struct)

An async sequence that publishes whenever an alarm changes.

[`alarmUpdates`](/documentation/AlarmKit/AlarmManager/alarmUpdates-swift.property)

An asynchronous sequence that emits events when the set of alarms changes.

[`alarms`](/documentation/AlarmKit/AlarmManager/alarms)

Fetches all alarms from the daemon that belong to the current client.

### Scheduling an alarm

[`schedule(id:configuration:)`](/documentation/AlarmKit/AlarmManager/schedule(id:configuration:))

Schedules a new alarm.

[`AlarmManager.AlarmConfiguration`](/documentation/AlarmKit/AlarmManager/AlarmConfiguration)

An object that contains all the properties necessary to schedule an alarm.

### Requesting authorization

[`requestAuthorization()`](/documentation/AlarmKit/AlarmManager/requestAuthorization())

Requests permission to use the alarm system if it hasn’t been requested before.

### Checking authorization status

[`AlarmManager.AlarmAuthorizationStateUpdates`](/documentation/AlarmKit/AlarmManager/AlarmAuthorizationStateUpdates)

An asynchronous sequence that publishes a new value when
authorization for the alarms and timers system changes.

[`authorizationUpdates`](/documentation/AlarmKit/AlarmManager/authorizationUpdates)

An asynchronous sequence that emits events when authorization to use
alarms changes.

[`AlarmManager.AuthorizationState`](/documentation/AlarmKit/AlarmManager/AuthorizationState-swift.enum)

An enumeration describing all authorization states for the client process.

[`authorizationState`](/documentation/AlarmKit/AlarmManager/authorizationState-swift.property)

Returns the current authorization state for this client.

### Changing an alarm state

[`cancel(id:)`](/documentation/AlarmKit/AlarmManager/cancel(id:))

Cancels the alarm with the specified ID.

[`countdown(id:)`](/documentation/AlarmKit/AlarmManager/countdown(id:))

Performs a countdown for the alarm with the specified ID if it’s currently alerting.

[`pause(id:)`](/documentation/AlarmKit/AlarmManager/pause(id:))

Pauses the alarm with the specified ID if it’s in the countdown
state.

[`resume(id:)`](/documentation/AlarmKit/AlarmManager/resume(id:))

Resumes the alarm with the specified ID if it’s in the paused state.

[`stop(id:)`](/documentation/AlarmKit/AlarmManager/stop(id:))

Stops the alarm with the specified ID.

### Throwing an error

[`AlarmManager.AlarmError`](/documentation/AlarmKit/AlarmManager/AlarmError)

An error that occurs when trying to schedule a timer.



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)
