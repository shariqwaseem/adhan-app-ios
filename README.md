# Athan

A beautiful, open-source Islamic prayer times app for iOS built with SwiftUI and Swift 6.

## Features

**Prayer Times** - Accurate daily times for Tahajjud, Fajr, Dhuhr, Asr, Maghrib, and Isha with a live countdown to the next prayer. Supports manual per-prayer time adjustments.

**Alarms & Notifications** - Three modes per prayer: silent, notification, or full alarm (iOS 26+) that plays the athan even in Silent Mode via [AlarmKit](https://developer.apple.com/documentation/alarmkit). Pre-alarm support for Fajr and Tahajjud (10-120 minutes before).

**Custom Alarms** - Create unlimited daily alarms independent of prayer times, each with its own delivery mode and athan sound.

**Qibla Compass** - Real-time compass-based Qibla direction with haptic feedback on alignment.

**Widgets** - Home screen and lock screen widgets in 6 sizes showing upcoming prayer times, countdowns, and Hijri dates.

**Ramadan** - Automatic detection with Suhoor/Iftar countdowns and day tracking.

**Localization** - English, Arabic (with full RTL support), Indonesian, and Turkish.

## Calculation Methods

13 methods with automatic selection based on your location:

Muslim World League, Egyptian General Authority, University of Islamic Sciences Karachi, Umm Al-Qura Makkah, Dubai, Moonsighting Committee, ISNA (North America), Kuwait, Qatar, Singapore, Shia (Jafari), Diyanet (Turkey), and manual selection.

Supports both Standard and Hanafi Asr juristic methods, plus high-latitude rules for regions above 48.5°.

## Tech Stack

- **SwiftUI** + **Swift 6** with strict concurrency
- **SwiftData** for persistence
- **AlarmKit** (iOS 26+) for native alarm scheduling
- **WidgetKit** for home screen and lock screen widgets
- **CoreLocation** for GPS, geocoding, and compass
- **BackgroundTasks** for automatic daily refresh
- [**adhan-swift**](https://github.com/batoulapps/adhan-swift) for prayer time calculations

## Requirements

- iOS 18.0+
- Xcode 16+
- AlarmKit features require iOS 26+

## Building

1. Clone the repository
2. Open the project in Xcode
3. Build and run on a device or simulator

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) — run `xcodegen generate` after cloning if the `.xcodeproj` needs to be regenerated.

## Athan Audio

17 built-in athan recordings from muezzins across the Islamic world. Each prayer can be assigned a different athan sound.

## License

This project is open source. See [LICENSE](LICENSE) for details.
