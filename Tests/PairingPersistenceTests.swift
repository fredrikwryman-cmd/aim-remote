import XCTest
@testable import AiMRemote

/// Fejkad nyckelring med riktiga grupper. Skillnaden mot FakeKeychain i
/// KeychainMigrationTests ar att en fraga alltid galler EN grupp: nil betyder
/// appens egen grupp, aldrig "alla grupper appen kommer at". Det ar exakt det
/// kontrakt SystemKeychainMover maste halla. Holl det inte, raderade
/// migreringen de delade posterna vid varje start.
private final class GroupedKeychain: KeychainMoving {
    let ownGroup = "TEAM.se.aim.remote"
    var groups: [String: Set<SharedItem>]
    private(set) var copies = 0
    private(set) var deletions: [(SharedItem, String)] = []

    init(own: Set<SharedItem>) { groups = [ownGroup: own] }

    private func scope(_ group: String?) -> String { group ?? ownGroup }

    func exists(_ item: SharedItem, group: String?) -> Bool {
        groups[scope(group)]?.contains(item) ?? false
    }

    func copy(_ item: SharedItem, to group: String) throws {
        guard groups[ownGroup]?.contains(item) == true else {
            throw AppFailure.message("Posten finns inte i appens egen grupp.")
        }
        copies += 1
        groups[group, default: []].insert(item)
    }

    func delete(_ item: SharedItem, group: String?) throws {
        let name = scope(group)
        groups[name]?.remove(item)
        deletions.append((item, name))
    }
}

@MainActor
final class PairingPersistenceTests: XCTestCase {

    private let shared = "TEAM.se.aim.remote.shared"

    // MARK: - Nyckelringen over tva appstarter

    func testSecondLaunchLeavesTheSharedItemsAlone() {
        let keychain = GroupedKeychain(own: [.clientKey, .clientCertificate, .tvList])

        // Forsta starten: allt flyttas till den delade gruppen.
        let first = KeychainMigrator.run(group: shared, using: keychain)
        XCTAssertEqual(Set(first.copied), Set(SharedItem.allCases))
        XCTAssertEqual(keychain.groups[shared], Set(SharedItem.allCases))
        XCTAssertEqual(keychain.groups[keychain.ownGroup], [])

        // Andra starten: ingenting kopieras och ingenting raderas.
        let copiesBefore = keychain.copies
        let deletionsBefore = keychain.deletions.count
        let second = KeychainMigrator.run(group: shared, using: keychain)

        XCTAssertEqual(second.copied, [])
        XCTAssertEqual(Set(second.alreadyShared), Set(SharedItem.allCases))
        XCTAssertEqual(second.removedOriginals, [],
                       "Andra starten far inte radera nagot: originalen ar redan borta.")
        XCTAssertEqual(keychain.copies, copiesBefore)
        XCTAssertEqual(keychain.deletions.count, deletionsBefore)

        // Och framfor allt: nyckeln, certifikatet och listan finns kvar delade.
        XCTAssertEqual(keychain.groups[shared], Set(SharedItem.allCases),
                       "De delade posterna maste overleva andra starten.")
    }

    func testMigrationNeverDeletesInTheSharedGroup() {
        let keychain = GroupedKeychain(own: [.clientKey])
        KeychainMigrator.run(group: shared, using: keychain)
        for (_, group) in keychain.deletions {
            XCTAssertEqual(group, keychain.ownGroup,
                           "Migreringen raderade i gruppen \(group).")
        }
        XCTAssertTrue(keychain.groups[shared]?.contains(.clientKey) == true)
    }

    func testNothingHappensWhenThereIsNothingToMove() {
        let keychain = GroupedKeychain(own: [])
        let report = KeychainMigrator.run(group: shared, using: keychain)
        XCTAssertEqual(Set(report.missing), Set(SharedItem.allCases))
        XCTAssertEqual(keychain.copies, 0)
        XCTAssertEqual(keychain.deletions.count, 0)
    }

    /// Appens egen grupp och den delade far aldrig vara samma strang: da skulle
    /// en radering av originalet traffa kopian.
    func testOwnGroupAndSharedGroupAreDifferent() {
        XCTAssertNotEqual(Shared.ownGroup, Shared.keychainGroup)
        XCTAssertTrue(Shared.keychainGroup.hasSuffix(Shared.keychainSuffix))
    }

    // MARK: - SavedTV over tva appstarter

    func testSavedTVAndFingerprintSurviveARestart() {
        let storage = MemoryTVStorage()
        let fingerprint = Data(repeating: 0xC3, count: 32)

        // Forsta starten: parkoppling.
        let first = SavedTVStore(storage: storage)
        let saved = first.upsert(name: "TCL 43P635", host: "192.168.1.40",
                                 fingerprint: fingerprint)
        XCTAssertEqual(first.activeID, saved.id)

        // Andra starten: samma lagring lases om.
        let second = SavedTVStore(storage: storage)
        XCTAssertEqual(second.all.count, 1)
        XCTAssertEqual(second.activeID, saved.id, "Aktiv TV ska vara samma efter omstart.")
        XCTAssertEqual(second.active?.fingerprint, fingerprint, "Fingeravtrycket ska vara samma.")
        XCTAssertEqual(second.active?.host, "192.168.1.40")

        // Och TV:n kanns igen pa sitt certifikat, utan ny parkoppling.
        XCTAssertEqual(
            TVTrust.decide(saved: second.all, host: "192.168.1.40",
                           fingerprint: fingerprint, pairing: false),
            .accept(id: saved.id, hostChanged: false)
        )
    }

    func testLegacyMigrationIsIdempotentAcrossLaunches() {
        let storage = MemoryTVStorage()
        let fingerprint = Data(repeating: 0xD4, count: 32)

        let first = SavedTVStore(storage: storage)
        let migrated = first.migrateLegacy(host: "192.168.1.41", name: "TCL",
                                           fingerprint: fingerprint)
        XCTAssertNotNil(migrated)
        XCTAssertEqual(first.all.count, 1)

        // Andra starten kor samma migrering igen: ingen dubblett, samma id.
        let second = SavedTVStore(storage: storage)
        let again = second.migrateLegacy(host: "192.168.1.41", name: "TCL",
                                         fingerprint: fingerprint)
        XCTAssertEqual(second.all.count, 1, "Migreringen far inte dubblera posten.")
        XCTAssertEqual(again?.id, migrated?.id)
        XCTAssertEqual(second.activeID, migrated?.id)
        XCTAssertEqual(second.active?.fingerprint, fingerprint)
    }

    func testARealCertificateChangeStillNeedsNewPairing() {
        let storage = MemoryTVStorage()
        let store = SavedTVStore(storage: storage)
        let known = Data(repeating: 0xE5, count: 32)
        let stranger = Data(repeating: 0xF6, count: 32)
        store.upsert(name: "TCL", host: "192.168.1.42", fingerprint: known)

        XCTAssertEqual(
            TVTrust.decide(saved: store.all, host: "192.168.1.42",
                           fingerprint: stranger, pairing: false),
            .mismatch(name: "TCL"),
            "Ett nytt certifikat pa en kand adress ska aldrig godtas tyst."
        )
    }

    // MARK: - Anslutningsloggen

    func testConnectionLogSurvivesARestartAndKeepsNoSecrets() {
        let suite = "tests.connection.log.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("Kunde inte oppna testdomanen.")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = ConnectionLog(defaults: defaults)
        first.record(ConnectionLogEntry(
            tvName: "TCL 43P635", host: "192.168.1.40", identity: "1a2b3c4d",
            expected: "aabbccdd11223344", presented: "aabbccdd11223344",
            result: "Ansluten", reason: ""
        ))

        let second = ConnectionLog(defaults: defaults)
        XCTAssertEqual(second.entries.count, 1, "Loggen ska overleva omstart.")
        XCTAssertEqual(second.entries.first?.identity, "1a2b3c4d")
        XCTAssertTrue(second.text.contains("192.168.1.40"))
        XCTAssertFalse(second.text.contains("BEGIN"), "Inget certifikat i loggen.")
        XCTAssertFalse(second.text.lowercased().contains("private"))
    }

    func testConnectionLogKeepsOnlyTheLastFifty() {
        let suite = "tests.connection.log.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return XCTFail("Kunde inte oppna testdomanen.")
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let log = ConnectionLog(defaults: defaults)
        for index in 1...60 {
            log.record(ConnectionLogEntry(
                tvName: "TCL", host: "10.0.0.\(index)", identity: "deadbeef",
                expected: "-", presented: "-", result: "Misslyckades",
                reason: "nr \(index)"
            ))
        }
        XCTAssertEqual(log.entries.count, ConnectionLog.limit)
        XCTAssertEqual(log.entries.first?.reason, "nr 11")
        XCTAssertEqual(log.entries.last?.reason, "nr 60")
    }

    func testShortDigestIsTruncatedHex() {
        XCTAssertEqual(ConnectionLog.short(Data([0xab, 0xcd, 0xef]), length: 4), "abcd")
        XCTAssertEqual(ConnectionLog.short(nil), "-")
        XCTAssertEqual(ConnectionLog.short(Data()), "-")
    }
}
