# Adhan

A beautiful, open-source Islamic prayer times app for iOS built with SwiftUI and Swift 6.

## Features

**Prayer Times** - Accurate daily times for Tahajjud, Fajr, Dhuhr, Asr, Maghrib, and Isha with a live countdown to the next prayer. Supports manual per-prayer time adjustments.

**Alarms & Notifications** - Three modes per prayer: silent, notification, or full alarm that plays the adhan even in Silent Mode via [AlarmKit](https://developer.apple.com/documentation/alarmkit). Pre-alarm support for Fajr and Tahajjud (10-120 minutes before).

**Custom Alarms** - Create unlimited daily alarms independent of prayer times, each with its own delivery mode and adhan sound.

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
- **AlarmKit** for native alarm scheduling
- **WidgetKit** for home screen and lock screen widgets
- **CoreLocation** for GPS, geocoding, and compass
- **BackgroundTasks** for automatic daily refresh
- [**adhan-swift**](https://github.com/batoulapps/adhan-swift) for prayer time calculations

## Requirements

- iOS 26.0+
- Xcode 16+

## Building

1. Clone the repository
2. Open the project in Xcode
3. Build and run on a device or simulator

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) — run `xcodegen generate` after cloning if the `.xcodeproj` needs to be regenerated.

## Adhan Audio

17 built-in adhan recordings from muezzins across the Islamic world. Each prayer can be assigned a different adhan sound.

## License

This project is open source. See [LICENSE](LICENSE) for details.
# Adhan

## App Store screenshots

Fastlane captures the Home, Qibla, and Settings screens in English, Arabic,
Indonesian, and Turkish on an iPhone 17 Pro simulator.

Framing happens at the simulator's native 1206x2622 so the device frame fits the
screenshot exactly, then `fastlane/resize_framed.py` rescales each `_framed.png`
to **1242x2688** — App Store Connect only accepts 1242x2688 or 1284x2778 in its
6.5" slot, and no current iPhone captures at those sizes. Raw (unframed)
screenshots stay at 1206x2622; the framed ones are what you upload.

```sh
brew install fastlane imagemagick librsvg
fastlane ios screenshots_framed
```

Requires fastlane 2.238.0 or newer — earlier releases have no iPhone 15/16/17
device frames and fail with `Unsupported screen size`. The simulator must be
named exactly `iPhone 17 Pro`; create it once with:

```sh
xcrun simctl create "iPhone 17 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

Raw and framed images are written to `fastlane/screenshots`, with an HTML
overview at `fastlane/screenshots/screenshots.html`.

Edit localized marketing captions in each language folder:

- `fastlane/screenshots/en-US`
- `fastlane/screenshots/ar`
- `fastlane/screenshots/id`
- `fastlane/screenshots/tr`

Use `fastlane ios screenshots` when you only need raw screenshots. To test one
language while editing, run `fastlane ios screenshots languages:en-US`.

To regenerate and frame only the Prayer Detail screenshot in all four languages
without deleting or reframing the other screens, run:

```sh
fastlane ios prayer_detail_screenshots
```
