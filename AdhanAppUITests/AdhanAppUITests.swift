import XCTest

@MainActor
final class AdhanAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppStoreScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app, waitForAnimations: false)
        if let screenshotsDirectory = Snapshot.screenshotsDirectory {
            try? FileManager.default.removeItem(at: screenshotsDirectory)
            try FileManager.default.createDirectory(
                at: screenshotsDirectory,
                withIntermediateDirectories: true
            )
        }
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-FASTLANE_SCREENSHOTS", "YES"
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))

        if app.launchArguments.contains("-PRAYER_DETAIL_SCREENSHOT_ONLY") {
            waitForScreenToSettle()
            capturePrayerDetail(in: app)
            return
        }

        waitForScreenToSettle()
        snapshot("01PrayerTimes")

        tabBar.buttons.element(boundBy: 1).tap()
        waitForScreenToSettle()
        snapshot("02Qibla")

        tabBar.buttons.element(boundBy: 2).tap()
        waitForScreenToSettle()
        snapshot("03Settings")

        // Relaunch instead of relying on a stale indexed tab query after taking
        // screenshots. XCUI can otherwise synthesize the tap against another
        // simulator process when several apps are installed.
        app.terminate()
        app.launch()

        capturePrayerDetail(in: app)

        let soundPicker = app.buttons["alarm-sound-picker"]
        XCTAssertTrue(soundPicker.waitForExistence(timeout: 5))
        soundPicker.tap()
        waitForScreenToSettle()
        snapshot("05AdhanSounds")
    }

    private func capturePrayerDetail(in app: XCUIApplication) {
        let fajrRow = app.buttons["prayer-row-fajr"]
        XCTAssertTrue(fajrRow.waitForExistence(timeout: 5))
        fajrRow.tap()
        waitForScreenToSettle()
        snapshot("04PrayerDetail")
    }

    private func waitForScreenToSettle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }
}
