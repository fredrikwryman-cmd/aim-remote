import XCTest

final class ScreenTests: XCTestCase {
    private func launch(onboarded: Bool = true, theme: String = "dark") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tr.remote.onboarded", onboarded ? "YES" : "NO",
            "-tr.remote.theme", theme,
            "-tr.remote.haptics", "YES"
        ]
        app.launch()
        return app
    }

    func testStartScreenOnFirstLaunch() {
        let app = launch(onboarded: false)
        XCTAssertTrue(app.staticTexts["Tech Rabbit Remote"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Din TV. Din kontroll."].exists)
        let next = app.buttons["Fortsätt till fjärrkontrollen"]
        XCTAssertTrue(next.exists)
        next.tap()
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 5))
    }

    func testRemoteAndSettingsTabs() {
        let app = launch()
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Inställningar"].exists)
        XCTAssertFalse(app.buttons["Enheter"].exists)
        XCTAssertFalse(app.buttons["Scener"].exists)

        // R02 enligt SPEC steg 1-3.
        XCTAssertTrue(app.buttons["Slå på eller av TV:n"].exists)
        XCTAssertTrue(app.buttons["Välj TV"].exists)
        XCTAssertTrue(app.buttons["Byt till ljust utseende"].exists)
        XCTAssertTrue(app.buttons["Sifferknappar"].exists)
        XCTAssertTrue(app.buttons["Bekräfta"].exists)
        XCTAssertTrue(app.buttons["Spola bakåt"].exists)
        XCTAssertTrue(app.staticTexts["Kanal"].exists)
        XCTAssertTrue(app.staticTexts["Volym"].exists)

        app.buttons["Inställningar"].tap()
        XCTAssertTrue(app.switches["Knappvibration"].waitForExistence(timeout: 3))
    }

    func testThemeButtonSwitchesTheme() {
        let app = launch(theme: "light")
        let toDark = app.buttons["Byt till mörkt utseende"]
        XCTAssertTrue(toDark.waitForExistence(timeout: 8))
        toDark.tap()
        XCTAssertTrue(app.buttons["Byt till ljust utseende"].waitForExistence(timeout: 3))
    }
}
