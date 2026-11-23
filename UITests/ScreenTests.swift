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
        XCTAssertTrue(app.staticTexts["Tech Rabbit Remote"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["Din TV. Din kontroll."].exists)
        let next = app.buttons["Fortsätt till fjärrkontrollen"]
        XCTAssertTrue(next.exists)
        next.tap()
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 10))
    }

    func testRemoteAndSettingsTabs() {
        let app = launch()
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 60))
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
    }

    // R03: rubrik, hero-kort, fyra rader och versionsrad. Ingen Enheter-rad.
    func testSettingsScreenRows() {
        let app = launch()
        XCTAssertTrue(app.buttons["Inställningar"].waitForExistence(timeout: 60))
        app.buttons["Inställningar"].tap()

        XCTAssertTrue(app.staticTexts["Inställningar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Tech Rabbit Remote, Din TV. Din kontroll."].exists)
        XCTAssertTrue(first(app, beginningWith: "TV och anslutning").exists)
        XCTAssertTrue(app.buttons["Hjälp"].exists)
        XCTAssertTrue(app.switches["Knappvibration"].exists)
        XCTAssertTrue(first(app, beginningWith: "Utseende").exists)
        XCTAssertTrue(app.staticTexts["v0.1.0 · Testversion"].exists)
    }

    // Utseende-bladet: tre val, bock vid valt lage, stangs med X.
    func testAppearancePanel() {
        let app = launch(theme: "dark")
        XCTAssertTrue(app.buttons["Inställningar"].waitForExistence(timeout: 60))
        app.buttons["Inställningar"].tap()
        let row = first(app, beginningWith: "Utseende")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.buttons["Ljust"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mörkt"].exists)
        XCTAssertTrue(app.buttons["Automatiskt"].exists)
        app.buttons["Ljust"].tap()
        app.buttons["Stäng"].tap()
        XCTAssertTrue(first(app, beginningWith: "Utseende").waitForExistence(timeout: 5))
    }

    // R04 Valj TV oppnas fran TV-ikonen och stangs med X.
    func testChooseTVPanel() {
        let app = launch()
        XCTAssertTrue(app.buttons["Välj TV"].waitForExistence(timeout: 60))
        app.buttons["Välj TV"].tap()
        XCTAssertTrue(app.staticTexts["Välj TV"].waitForExistence(timeout: 5))
        app.buttons["Stäng"].tap()
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 5))
    }

    // Tangentbordspanelen: tre separata knappar.
    func testKeyboardPanel() {
        let app = launch()
        XCTAssertTrue(app.buttons["Öppna tangentbord"].waitForExistence(timeout: 60))
        app.buttons["Öppna tangentbord"].tap()
        XCTAssertTrue(app.staticTexts["Tangentbord"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Radera ett tecken"].exists)
        XCTAssertTrue(app.buttons["Enter eller sök"].exists)
        XCTAssertTrue(app.buttons["Skicka text"].exists)
        app.buttons["Stäng"].tap()
    }

    func testThemeButtonSwitchesTheme() {
        let app = launch(theme: "light")
        let toDark = app.buttons["Byt till mörkt utseende"]
        XCTAssertTrue(toDark.waitForExistence(timeout: 60))
        // Temaknappens accessibilityValue är appearanceRaw. Läs det före och
        // efter trycket, så att felmeddelandet visar om trycket nådde fram.
        let before = toDark.value as? String ?? "(inget värde)"
        // Ett vanligt tap på elementet nådde aldrig fram: den samtidiga
        // långtrycksgesten åt upp det syntetiserade trycket. Ett tryck på
        // knappens mittkoordinat går förbi den.
        toDark.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let switched = app.buttons["Byt till ljust utseende"].waitForExistence(timeout: 5)
        let themeButton = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Byt till"))
            .firstMatch
        let after = themeButton.value as? String ?? "(inget värde)"
        XCTAssertTrue(switched, "appearanceRaw före trycket: \(before), efter: \(after)")
    }

    private func first(_ app: XCUIApplication, beginningWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }
}
