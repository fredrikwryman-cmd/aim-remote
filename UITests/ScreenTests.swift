import XCTest

final class ScreenTests: XCTestCase {
    func testLaunchRemoteAndSettings() {
        let app = XCUIApplication()
        app.launch()

        // Startskärmen visas kort och går att hoppa över.
        XCTAssertTrue(app.staticTexts["Tech Rabbit Remote"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Din TV. Din kontroll."].exists)
        attach(app, "00-Start")
        let skip = app.buttons["Fortsätt till fjärrkontrollen"]
        if skip.waitForExistence(timeout: 3) { skip.tap() }

        // Flikraden har bara Fjärr och Inställningar.
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Inställningar"].exists)
        XCTAssertFalse(app.buttons["Enheter"].exists)
        XCTAssertFalse(app.buttons["Scener"].exists)

        // Fjärrens knappar enligt designen.
        XCTAssertTrue(app.buttons["Slå på eller av TV:n"].exists)
        XCTAssertTrue(app.buttons["TV och anslutning"].exists)
        XCTAssertTrue(app.buttons["Bekräfta"].exists)
        XCTAssertTrue(app.buttons["Sifferknappar"].exists)
        XCTAssertTrue(app.buttons["Höj volymen"].exists)
        XCTAssertTrue(app.buttons["Nästa kanal"].exists)
        XCTAssertTrue(first(app, beginningWith: "Byt till").exists)
        attach(app, "01-Fjarr")

        app.buttons["Inställningar"].tap()
        XCTAssertTrue(app.switches["Knappvibration"].waitForExistence(timeout: 3))
        XCTAssertTrue(first(app, beginningWith: "TV och anslutning").exists)
        XCTAssertTrue(app.buttons["Hjälp"].exists)
        attach(app, "02-Installningar")
    }

    func testAppearanceSettingAndToggle() {
        let app = XCUIApplication()
        app.launch()
        let skip = app.buttons["Fortsätt till fjärrkontrollen"]
        if skip.waitForExistence(timeout: 8) { skip.tap() }

        // Utseende finns som inställning med tre val.
        XCTAssertTrue(app.buttons["Inställningar"].waitForExistence(timeout: 8))
        app.buttons["Inställningar"].tap()
        let appearanceRow = first(app, beginningWith: "Utseende")
        XCTAssertTrue(appearanceRow.waitForExistence(timeout: 3))
        appearanceRow.tap()
        XCTAssertTrue(app.buttons["Automatiskt"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Ljust"].exists)
        XCTAssertTrue(app.buttons["Mörkt"].exists)
        app.buttons["Ljust"].tap()
        app.buttons["Klart"].tap()

        // Sol- och månknappen växlar direkt till det andra temat.
        app.buttons["Fjärr"].tap()
        XCTAssertTrue(app.buttons["Byt till mörkt utseende"].waitForExistence(timeout: 3))
        app.buttons["Byt till mörkt utseende"].tap()
        XCTAssertTrue(app.buttons["Byt till ljust utseende"].waitForExistence(timeout: 3))
        attach(app, "03-Morkt-tema")
    }

    private func first(_ app: XCUIApplication, beginningWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
