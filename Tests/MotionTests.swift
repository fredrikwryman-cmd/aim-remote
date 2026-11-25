import XCTest
@testable import AiMRemote

// Haptikspärren i punkt 2: aldrig två haptiker inom 80 ms.
final class MotionTests: XCTestCase {

    func testFirstHapticIsAllowed() {
        var gate = HapticGate()
        XCTAssertTrue(gate.allows(at: 10))
    }

    func testTwoHapticsWithinEightyMillisecondsAreBlocked() {
        var gate = HapticGate()
        XCTAssertTrue(gate.allows(at: 10))
        XCTAssertFalse(gate.allows(at: 10.01))
        XCTAssertFalse(gate.allows(at: 10.079))
    }

    func testEightyMillisecondsLaterIsAllowed() {
        var gate = HapticGate()
        XCTAssertTrue(gate.allows(at: 10))
        XCTAssertTrue(gate.allows(at: 10.08))
    }

    /// Ett nekat anrop får inte flytta fönstret framåt: annars skulle en
    /// skur av anrop skjuta nästa tillåtna haptik på framtiden.
    func testABlockedHapticDoesNotMoveTheWindow() {
        var gate = HapticGate()
        XCTAssertTrue(gate.allows(at: 10))
        XCTAssertFalse(gate.allows(at: 10.05))
        XCTAssertFalse(gate.allows(at: 10.06))
        XCTAssertTrue(gate.allows(at: 10.08))
    }

    /// Hållrepetitionen i TRKey ligger på 120 ms och ska alltså vibrera
    /// varje gång.
    func testKeyRepeatPassesTheGate() {
        var gate = HapticGate()
        var allowed = 0
        for step in 0..<5 {
            if gate.allows(at: 1 + Double(step) * 0.12) { allowed += 1 }
        }
        XCTAssertEqual(allowed, 5)
    }

    func testTheGateIsEightyMilliseconds() {
        XCTAssertEqual(HapticGate.minimumInterval, 0.08, accuracy: 0.0001)
    }

    // Felmallen i punkt 6: vad hände, vad betyder det, vad gör jag nu.
    func testNoticeFollowsTheTemplate() {
        let text = NoticeText.from("TV:n kunde inte nås. Kontrollera att den är på.")
        XCTAssertEqual(text.what, "Hittar inte TV:n.")
        XCTAssertFalse(text.means.isEmpty)
        XCTAssertFalse(text.next.isEmpty)
    }

    func testUnknownNoticeKeepsItsTextAndStillSaysWhatToDo() {
        let text = NoticeText.from("Något oväntat hände.")
        XCTAssertEqual(text.what, "Något oväntat hände.")
        XCTAssertTrue(text.means.isEmpty)
        XCTAssertFalse(text.next.isEmpty)
    }

    func testCertificateNoticeAsksForPairing() {
        let text = NoticeText.from(
            "TV:n på 192.168.1.40 visar ett annat certifikat än TCL. Parkoppla igen om det är din TV.")
        XCTAssertTrue(text.next.contains("Parkoppla"))
    }
}
