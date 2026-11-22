import XCTest

// Skärmbilder av R01 och R02 (ljust och mörkt) för jämförelse mot
// designpaketets bilder i skarmar/. Körs av .github/workflows/screenshots.yml.
final class DesignShotTests: XCTestCase {
    func testShotR01Start() {
        let app = launch(onboarded: false, theme: "dark")
        XCTAssertTrue(app.staticTexts["Tech Rabbit Remote"].waitForExistence(timeout: 10))
        shoot(app, "R01_start_dark")
    }

    func testShotR02RemoteDark() {
        let app = launch(onboarded: true, theme: "dark")
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 10))
        shoot(app, "R02_fjarr_dark")
    }

    func testShotR02RemoteLight() {
        let app = launch(onboarded: true, theme: "light")
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 10))
        shoot(app, "R02_fjarr_light")
    }

    private func launch(onboarded: Bool, theme: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tr.remote.onboarded", onboarded ? "YES" : "NO",
            "-tr.remote.theme", theme,
            "-tr.remote.haptics", "NO"
        ]
        app.launch()
        return app
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
