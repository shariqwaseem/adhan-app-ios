import XCTest

@MainActor
final class AdhanAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppStoreScreenshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app, waitForAnimations: false)
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-FASTLANE_SCREENSHOTS", "YES"
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))

        waitForScreenToSettle()
        snapshot("01PrayerTimes")

        let fajrRow = app.buttons["prayer-row-fajr"]
        XCTAssertTrue(fajrRow.waitForExistence(timeout: 5))
        fajrRow.tap()
        waitForScreenToSettle()
        snapshot("04PrayerDetail")

        let soundPicker = app.buttons["alarm-sound-picker"]
        XCTAssertTrue(soundPicker.waitForExistence(timeout: 5))
        soundPicker.tap()
        waitForScreenToSettle()
        snapshot("05AdhanSounds")

        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons.element(boundBy: 1).tap()
        waitForScreenToSettle()
        snapshot("02Qibla")

        tabBar.buttons.element(boundBy: 2).tap()
        waitForScreenToSettle()
        snapshot("03Settings")
    }

    private func waitForScreenToSettle() {
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }
}
