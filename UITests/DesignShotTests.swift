import XCTest

// Skärmbilder av R01 Start, R02 Fjärr, R03 Inställningar, R04 Välj TV och
// panelerna TV och anslutning, 123 (Sifferknappar), Tangentbord och Hjälp,
// i ljust och mörkt läge, för jämförelse mot designpaketets bilder i
// skarmar/. Körs av .github/workflows/screenshots.yml.
//
// Varje tema går i en körning: appen startas en gång och skärmarna fotas i
// tur och ordning, så att körtiden räcker till alla sexton bilder.
final class DesignShotTests: XCTestCase {

    // MARK: - R01 Start

    func testShotR01StartDark() {
        let app = launch(onboarded: false, theme: "dark")
        XCTAssertTrue(app.staticTexts["Tech Rabbit Remote"].waitForExistence(timeout: 60))
        shoot(app, "R01_start_dark")
    }

    // R01 ritas alltid i mörkt läge enligt SPEC. Bilden tas även med ljust
    // valt tema, för att visa att starten inte följer temat.
    func testShotR01StartLight() {
        let app = launch(onboarded: false, theme: "light")
        XCTAssertTrue(app.staticTexts["Tech Rabbit Remote"].waitForExistence(timeout: 60))
        shoot(app, "R01_start_light")
    }

    // MARK: - Allt i mörkt och ljust läge

    func testShotsDark() { walk(theme: "dark") }

    func testShotsLight() { walk(theme: "light") }

    // MARK: - Vandringen

    private func walk(theme: String) {
        let app = launch(onboarded: true, theme: theme)
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 60))

        // R02 Fjärr
        shoot(app, "R02_fjarr_\(theme)")

        // R04 Välj TV
        openPanel(app, tap: app.buttons["Välj TV"], title: "Välj TV", name: "R04_valj-tv_\(theme)")

        // Panelen 123 (Sifferknappar)
        openPanel(app, tap: app.buttons["Sifferknappar"], title: "Sifferknappar", name: "P05_123_\(theme)")

        // Panelen Tangentbord
        openPanel(app, tap: app.buttons["Öppna tangentbord"], title: "Tangentbord", name: "P06_tangentbord_\(theme)")

        // R03 Inställningar
        app.buttons["Inställningar"].tap()
        XCTAssertTrue(app.staticTexts["Inställningar"].waitForExistence(timeout: 10))
        shoot(app, "R03_installningar_\(theme)")

        // Panelen TV och anslutning
        openPanel(app, tap: row(app, beginningWith: "TV och anslutning"),
                  title: "TV och anslutning", name: "P07_tv-och-anslutning_\(theme)")

        // Panelen Hjälp
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
