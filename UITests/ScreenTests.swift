import XCTest

final class ScreenTests: XCTestCase {
    func testTwoMainScreens() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Inställningar"].exists)
        XCTAssertFalse(app.buttons["Touchpad"].exists)
        XCTAssertFalse(app.buttons["Apps"].exists)
        attach(app, "01-Fjarr")
        app.buttons["Inställningar"].tap()
        XCTAssertTrue(app.switches["Knappvibration"].waitForExistence(timeout: 3))
        attach(app, "02-Installningar")
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
