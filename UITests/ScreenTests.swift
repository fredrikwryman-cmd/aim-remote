import XCTest
import UIKit

final class ScreenTests: XCTestCase {
    private func launch(onboarded: Bool = true, theme: String = "dark") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tr.remote.onboarded", onboarded ? "YES" : "NO",
            "-tr.remote.haptics", "YES",
            "-tr.remote.theme", theme
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

    // Valet "Folj telefonen" ska ge samma lage som telefonen. Testet laser
    // simulatorns utseende ur testloparens egen traitCollection och jamfor med
    // fargen appen faktiskt malar i bakgrunden.
    func testAppFollowsSystemAppearance() {
        let app = launch(theme: "system")
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 60))

        // Den gamla temaknappen pa fjarren finns inte kvar: valet gors i
        // Installningar.
        XCTAssertFalse(app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Byt till"))
            .firstMatch.exists)

        let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        // Bakgrunden ar #EEF0F2 i ljust lage och #071015 i morkt.
        let luma = settledBackgroundLuma(of: app) {
            systemIsDark ? $0 < 0.35 : $0 > 0.65
        }
        if systemIsDark {
            XCTAssertLessThan(luma, 0.35,
                              "Systemet ar i morkt lage men appen ritar ljust (luma \(luma)).")
        } else {
            XCTAssertGreaterThan(luma, 0.65,
                                 "Systemet ar i ljust lage men appen ritar morkt (luma \(luma)).")
        }
    }

    // Valet Morkt ska ge morkt aven nar telefonen star i ljust lage.
    func testDarkChoiceStaysDarkWhenSystemIsLight() {
        let app = launch(theme: "dark")
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 60))
        let luma = settledBackgroundLuma(of: app) { $0 < 0.35 }
        XCTAssertLessThan(luma, 0.35,
                          "Valet Morkt ska rita morkt oavsett telefonens lage (luma \(luma)).")
    }

    // Utseende-panelen listar de tre lagena och visar vilket som ar valt.
    func testAppearancePanelHasThreeModes() {
        let app = launch(theme: "dark")
        XCTAssertTrue(app.buttons["Inställningar"].waitForExistence(timeout: 60))
        app.buttons["Inställningar"].tap()
        first(app, beginningWith: "Utseende").tap()

        XCTAssertTrue(app.staticTexts["Utseende"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mörkt"].exists)
        XCTAssertTrue(app.buttons["Ljust"].exists)
        XCTAssertTrue(app.buttons["Följ telefonen"].exists)
        XCTAssertTrue(app.buttons["Mörkt"].isSelected,
                      "Morkt ar standard och ska vara markerat.")
        app.buttons["Stäng"].tap()
    }

    /// preferredColorScheme gar via fonstret, sa den forsta bildrutan kan annu
    /// vara ritad i systemets lage. Darfor lases bakgrunden om tills den
    /// stamt eller tiden gatt ut, och sista varde returneras antingen vag.
    private func settledBackgroundLuma(of app: XCUIApplication,
                                       timeout: TimeInterval = 10,
                                       where matches: (CGFloat) -> Bool) -> CGFloat {
        let deadline = Date().addingTimeInterval(timeout)
        var last: CGFloat = -1
        repeat {
            if let luma = backgroundLuma(of: app) {
                last = luma
                if matches(luma) { return luma }
            }
            _ = app.buttons["Fjärr"].waitForExistence(timeout: 0.4)
        } while Date() < deadline
        return last
    }

    /// Ljusheten i en punkt uppe till vanster, dar bara bakgrunden ligger.
    private func backgroundLuma(of app: XCUIApplication) -> CGFloat? {
        guard let cg = app.screenshot().image.cgImage else { return nil }
        let x = Int(CGFloat(cg.width) * 0.04)
        let y = Int(CGFloat(cg.height) * 0.10)
        guard let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let offset = y * cg.bytesPerRow + x * (cg.bitsPerPixel / 8)
        guard offset + 2 < CFDataGetLength(data) else { return nil }
        let c0 = CGFloat(bytes[offset]) / 255
        let c1 = CGFloat(bytes[offset + 1]) / 255
        let c2 = CGFloat(bytes[offset + 2]) / 255
        return (c0 + c1 + c2) / 3
    }

    private func first(_ app: XCUIApplication, beginningWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }
}
