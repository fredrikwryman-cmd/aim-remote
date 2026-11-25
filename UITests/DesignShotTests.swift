import XCTest
import UIKit

// Skärmbilder av R01 Start, Fjärr, Inställningar, Välj TV och panelerna
// TV och anslutning, 123 (Sifferknappar), Tangentbord och Hjälp, för
// jämförelse mot facit i design/referenser/v2/.
// Körs av .github/workflows/screenshots.yml.
//
// Temat sätts på simulatorn före körningen med
// `xcrun simctl ui <udid> appearance light|dark`. Testlöparen följer samma
// läge, så bilderna namnges efter det den själv ser, och appen startas med
// `-tr.remote.theme` satt till samma läge.
final class DesignShotTests: XCTestCase {

    private var theme: String {
        UITraitCollection.current.userInterfaceStyle == .dark ? "dark" : "light"
    }

    // MARK: - R01 Start

    func testShotR01Start() {
        let app = launch(onboarded: false)
        XCTAssertTrue(app.staticTexts["Tech Rabbit Remote"].waitForExistence(timeout: 60))
        shoot(app, "R01_start_\(theme)")
    }

    // MARK: - Vandringen genom skärmarna

    func testShots() {
        let app = launch(onboarded: true)
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 60))

        // Fjärr (facit sid 1 ljust, sid 2 mörkt)
        shoot(app, "R02_fjarr_\(theme)")

        openPanel(app, tap: app.buttons["Välj TV"], title: "Välj TV", name: "R04_valj-tv_\(theme)")
        openPanel(app, tap: app.buttons["Sifferknappar"], title: "Sifferknappar", name: "P05_123_\(theme)")
        openPanel(app, tap: app.buttons["Öppna tangentbord"], title: "Tangentbord", name: "P06_tangentbord_\(theme)")

        // Inställningar (facit sid 3 ljust, sid 4 mörkt)
        app.buttons["Inställningar"].tap()
        XCTAssertTrue(app.staticTexts["Inställningar"].waitForExistence(timeout: 10))
        shoot(app, "R03_installningar_\(theme)")

        openPanel(app, tap: row(app, beginningWith: "TV och anslutning"),
                  title: "TV och anslutning", name: "P07_tv-och-anslutning_\(theme)")
        openPanel(app, tap: row(app, beginningWith: "Hjälp"),
                  title: "Hjälp", name: "P08_hjalp_\(theme)")
    }

    private func openPanel(_ app: XCUIApplication, tap opener: XCUIElement,
                           title: String, name: String) {
        XCTAssertTrue(opener.waitForExistence(timeout: 10), "hittade inte knappen till \(title)")
        opener.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10),
                      "panelen \(title) öppnades inte")
        shoot(app, name)
        let close = app.buttons["Stäng"].firstMatch
        if close.waitForExistence(timeout: 5) { close.tap() }
    }

    private func row(_ app: XCUIApplication, beginningWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func launch(onboarded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tr.remote.onboarded", onboarded ? "YES" : "NO",
            "-tr.remote.haptics", "YES",
            // Utseendet valjs numera i appen, och standard ar morkt. Bilderna
            // ska visa samma lage som simulatorn, sa valet satts till det.
            "-tr.remote.theme", theme
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
