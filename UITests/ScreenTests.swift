import XCTest
import UIKit

// Sokningen i Valj TV byter laddningsskelett mot tomt lage efter ca 8 s, eller
// mot en lista om en TV svarar. Bada ar vila; skelettet ar det inte. Skelettet
// ligger i hierarkin som en Alert med etiketten "Söker efter TV-apparater", och
// XCTest letar efter avbrytande element fore varje tryck. Forsvinner skelettet
// mellan letandet och trycket faller trycket pa en snapshot som inte langre
// finns, och det ar den ostadigheten testerna rakade ut for.
func waitUntilSearchHasSettled(_ app: XCUIApplication,
                               timeout: TimeInterval = 30) -> Bool {
    let skeleton = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label == %@", "Söker efter TV-apparater"))
        .firstMatch
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if !skeleton.exists { return true }
        _ = skeleton.waitForExistence(timeout: 0.3)
    }
    return !skeleton.exists
}

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

        XCTAssertTrue(app.buttons["Hjälp"].waitForExistence(timeout: 15),
                      "fliken Inställningar öppnades inte")
        XCTAssertTrue(app.staticTexts["Inställningar"].waitForExistence(timeout: 10))
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
        let title = app.staticTexts["Välj TV"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))

        // Medan sokningen pagar ligger laddningsskelettet i hierarkin som en
        // Alert med etiketten "Söker efter TV-apparater". XCTest letar efter
        // avbrytande element fore varje tryck, och om skelettet forsvinner
        // mellan letandet och trycket faller trycket pa en snapshot som inte
        // langre finns. Darfor vantar testet ut sokningen forst.
        XCTAssertTrue(waitUntilSearchHasSettled(app), "sokningen i Välj TV kom aldrig i vila")

        let close = app.buttons["Stäng"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(waitForDisappearance(title), "panelen stangdes inte med X")
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 10))
    }

    // Tangentbordspanelen: tre separata knappar.
    func testKeyboardPanel() {
        let app = launch()
        XCTAssertTrue(app.buttons["Öppna tangentbord"].waitForExistence(timeout: 60))
        app.buttons["Öppna tangentbord"].tap()
        let title = app.staticTexts["Tangentbord"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Radera ett tecken"].exists)
        XCTAssertTrue(app.buttons["Enter eller sök"].exists)
        XCTAssertTrue(app.buttons["Skicka text"].exists)
        let close = app.buttons["Stäng"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()
        XCTAssertTrue(waitForDisappearance(title), "tangentbordspanelen stangdes inte")
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
        let row = first(app, beginningWith: "Utseende")
        XCTAssertTrue(row.waitForExistence(timeout: 15), "raden Utseende hittades inte")
        row.tap()

        XCTAssertTrue(app.staticTexts["Utseende"].waitForExistence(timeout: 10))
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

    /// Vantar tills elementet ar borta. waitForExistence svarar direkt nar
    /// elementet finns, sa den kan inte anvandas at andra hallet.
    private func waitForDisappearance(_ element: XCUIElement,
                                      timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return !element.exists
    }
}

// MARK: - Beteendet ur direktiv 23

final class BehaviourTests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-tr.remote.onboarded", "YES",
            "-tr.remote.haptics", "YES",
            "-tr.remote.theme", "dark"
        ]
        app.launch()
        return app
    }

    // Punkt 8 och 10: panelen stangs bade med stangknappen och med ett
    // nedsvep, och nedsvepet far inte blockeras av animationen.
    func testPanelClosesWithTheCloseButtonAndWithADragDown() {
        let app = launch()
        XCTAssertTrue(app.buttons["Välj TV"].waitForExistence(timeout: 60))

        app.buttons["Välj TV"].tap()
        let title = app.staticTexts["Välj TV"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilSearchHasSettled(app), "sokningen kom aldrig i vila")
        app.buttons["Stäng"].tap()
        XCTAssertTrue(waitForDisappearance(title), "panelen stangdes inte med X")

        app.buttons["Välj TV"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilSearchHasSettled(app), "sokningen kom aldrig i vila")
        let start = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 420))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(waitForDisappearance(title), "panelen stangdes inte med nedsvep")
        XCTAssertTrue(app.buttons["Fjärr"].waitForExistence(timeout: 10))
    }

    // Punkt 14: Glom TV kraver bekraftelse, och konsekvensen star i klartext.
    func testForgetAsksForConfirmationFirst() {
        let app = launch()
        XCTAssertTrue(app.buttons["Inställningar"].waitForExistence(timeout: 60))
        app.buttons["Inställningar"].tap()
        XCTAssertTrue(app.buttons["Hjälp"].waitForExistence(timeout: 15),
                      "fliken Inställningar öppnades inte")

        let row = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "TV och anslutning"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.staticTexts["TV och anslutning"].waitForExistence(timeout: 10))

        let forget = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Glöm "))
            .firstMatch
        XCTAssertTrue(forget.waitForExistence(timeout: 10))
        for _ in 0..<4 where !forget.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        forget.tap()

        let consequence = app.staticTexts[
            "Du måste skriva in koden från TV:n igen för att ansluta."]
        XCTAssertTrue(consequence.waitForExistence(timeout: 10),
                      "bekraftelsearket saknade konsekvensen i klartext")
        XCTAssertTrue(app.buttons["Avbryt"].exists, "arket saknade Avbryt")
        app.buttons["Avbryt"].tap()
        XCTAssertTrue(app.staticTexts["TV och anslutning"].waitForExistence(timeout: 10))
    }

    // Punkt 11 och 12: skelett medan sokningen pagar, sedan tomt lage med
    // forklaring och knappen Sok igen.
    func testChooseTVShowsTheEmptyStateWhenNothingIsFound() {
        let app = launch()
        XCTAssertTrue(app.buttons["Välj TV"].waitForExistence(timeout: 60))
        app.buttons["Välj TV"].tap()
        XCTAssertTrue(app.staticTexts["Välj TV"].waitForExistence(timeout: 10))

        let explanation = app.staticTexts[
            "Ingen TV hittades. Kontrollera att TV:n är på och på samma wifi."]
        XCTAssertTrue(explanation.waitForExistence(timeout: 30),
                      "tomt lage visades inte i Valj TV")
        XCTAssertTrue(app.buttons["Sök igen"].exists, "tomt lage saknade Sok igen")
    }

    private func waitForDisappearance(_ element: XCUIElement,
                                      timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return !element.exists
    }
}
