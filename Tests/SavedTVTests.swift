import XCTest
@testable import AiMRemote

final class SavedTVTests: XCTestCase {
    private let tclPrint = Data(repeating: 0xA1, count: 32)
    private let otherPrint = Data(repeating: 0xB2, count: 32)

    private func store() -> SavedTVStore {
        SavedTVStore(storage: MemoryTVStorage())
    }

    // MARK: - Migrering

    func testMigrationMovesTheOldTVIntoTheList() {
        let store = store()
        let migrated = store.migrateLegacy(host: "192.168.1.40", name: "TCL 43P635", fingerprint: tclPrint)

        XCTAssertNotNil(migrated)
        XCTAssertEqual(store.all.count, 1)
        XCTAssertEqual(store.all.first?.name, "TCL 43P635")
        XCTAssertEqual(store.all.first?.host, "192.168.1.40")
        XCTAssertEqual(store.all.first?.fingerprint, tclPrint)
        XCTAssertEqual(store.activeID, migrated?.id, "Den migrerade TV:n ska bli aktiv.")
    }

    func testMigrationCanBeRunAgainWithoutDuplicating() {
        let store = store()
        let first = store.migrateLegacy(host: "192.168.1.40", name: "TCL 43P635", fingerprint: tclPrint)
        let second = store.migrateLegacy(host: "192.168.1.40", name: "TCL 43P635", fingerprint: tclPrint)

        XCTAssertEqual(store.all.count, 1)
        XCTAssertEqual(first?.id, second?.id)
    }

    func testMigrationWithoutPinningDoesNothing() {
        let store = store()
        XCTAssertNil(store.migrateLegacy(host: "192.168.1.40", name: "TCL", fingerprint: nil))
        XCTAssertTrue(store.all.isEmpty)
        XCTAssertNil(store.activeID)
    }

    func testTheListSurvivesANewStore() {
        let storage = MemoryTVStorage()
        let first = SavedTVStore(storage: storage)
        first.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)

        let second = SavedTVStore(storage: storage)
        XCTAssertEqual(second.all.count, 1)
        XCTAssertEqual(second.all.first?.fingerprint, tclPrint)
        XCTAssertEqual(second.activeID, first.activeID)
    }

    // MARK: - Certifikat och adress

    func testACertificateChangeOnAKnownHostIsStopped() {
        let store = store()
        store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)

        let decision = TVTrust.decide(
            saved: store.all, host: "192.168.1.40", fingerprint: otherPrint, pairing: false
        )

        XCTAssertEqual(decision, .mismatch(name: "TCL 43P635"))
    }

    func testTheSameCertificateOnANewAddressUpdatesTheHost() {
        let store = store()
        let saved = store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)

        let decision = TVTrust.decide(
            saved: store.all, host: "192.168.1.77", fingerprint: tclPrint, pairing: false
        )
        XCTAssertEqual(decision, .accept(id: saved.id, hostChanged: true))

        store.upsert(name: "TCL 43P635", host: "192.168.1.77", fingerprint: tclPrint, makeActive: false)
        XCTAssertEqual(store.all.count, 1, "Samma certifikat ska inte ge en ny post.")
        XCTAssertEqual(store.all.first?.host, "192.168.1.77")
        XCTAssertEqual(store.all.first?.id, saved.id)
        XCTAssertEqual(store.all.first?.fingerprint, tclPrint, "Fingeravtrycket byts aldrig.")
    }

    func testTheSameCertificateOnTheSameAddressIsAcceptedWithoutChange() {
        let store = store()
        let saved = store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)
        let decision = TVTrust.decide(
            saved: store.all, host: "192.168.1.40", fingerprint: tclPrint, pairing: false
        )
        XCTAssertEqual(decision, .accept(id: saved.id, hostChanged: false))
    }

    func testAnUnknownTVIsNotAcceptedWithoutPairing() {
        let store = store()
        store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)
        let decision = TVTrust.decide(
            saved: store.all, host: "192.168.1.99", fingerprint: otherPrint, pairing: false
        )
        XCTAssertEqual(decision, .unknown)
    }

    func testPairingAcceptsTheCertificateItIsAbout() {
        let store = store()
        store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)
        let decision = TVTrust.decide(
            saved: store.all, host: "192.168.1.40", fingerprint: otherPrint, pairing: true
        )
        XCTAssertEqual(decision, .pairing)
    }

    // MARK: - Glöm

    func testForgettingOneOfTwoKeepsTheOther() {
        let store = store()
        let tcl = store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)
        let sony = store.upsert(name: "Sony Bravia", host: "192.168.1.55", fingerprint: otherPrint)
        XCTAssertEqual(store.activeID, sony.id)

        store.forget(id: tcl.id, alsoClearTrustStore: false)

        XCTAssertEqual(store.all.count, 1)
        XCTAssertEqual(store.all.first?.id, sony.id)
        XCTAssertEqual(store.activeID, sony.id, "Den aktiva TV:n ska vara kvar.")
        XCTAssertNil(store.tv(id: tcl.id))
        XCTAssertNil(store.tv(fingerprint: tclPrint))
    }

    func testForgettingTheActiveTVLeavesNoActiveTV() {
        let store = store()
        let tcl = store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)
        store.upsert(name: "Sony Bravia", host: "192.168.1.55", fingerprint: otherPrint)
        store.setActive(tcl.id)

        store.forget(id: tcl.id, alsoClearTrustStore: false)

        XCTAssertNil(store.activeID, "Utan aktiv TV ska appen vara Inte ansluten.")
        XCTAssertEqual(store.all.count, 1)
    }

    func testAForgottenTVIsNoLongerTrusted() {
        let store = store()
        let tcl = store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)
        store.forget(id: tcl.id, alsoClearTrustStore: false)

        let decision = TVTrust.decide(
            saved: store.all, host: "192.168.1.40", fingerprint: tclPrint, pairing: false
        )
        XCTAssertEqual(decision, .unknown, "Utan post finns ingen pinning kvar.")
    }

    // MARK: - Flera TV-apparater

    func testTwoTVsAreKeptApartByCertificate() {
        let store = store()
        let tcl = store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)
        let sony = store.upsert(name: "Sony Bravia", host: "192.168.1.55", fingerprint: otherPrint)

        XCTAssertEqual(store.all.count, 2)
        XCTAssertNotEqual(tcl.id, sony.id)
        XCTAssertEqual(store.tv(fingerprint: tclPrint)?.id, tcl.id)
        XCTAssertEqual(store.tv(host: "192.168.1.55")?.id, sony.id)
    }

    func testSwitchingActiveTV() {
        let store = store()
        let tcl = store.upsert(name: "TCL 43P635", host: "192.168.1.40", fingerprint: tclPrint)
        store.upsert(name: "Sony Bravia", host: "192.168.1.55", fingerprint: otherPrint)

        store.setActive(tcl.id)
        XCTAssertEqual(store.active?.id, tcl.id)
        XCTAssertEqual(store.active?.name, "TCL 43P635")
    }
}
