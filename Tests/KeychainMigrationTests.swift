import XCTest
@testable import AiMRemote

/// Fejkad nyckelring: posterna ligger i en grupp var, nil är appens egen.
private final class FakeKeychain: KeychainMoving {
    var own: Set<SharedItem>
    var shared: Set<SharedItem> = []
    /// Poster som vägrar kopiera, för att pröva att originalet lämnas kvar.
    var refuseCopy: Set<SharedItem> = []
    /// Poster där kopian "försvinner" direkt, så att verifieringen faller.
    var copyWithoutLanding: Set<SharedItem> = []
    private(set) var copies = 0
    private(set) var deletions: [SharedItem] = []

    init(own: Set<SharedItem>) { self.own = own }

    func exists(_ item: SharedItem, group: String?) -> Bool {
        group == nil ? own.contains(item) : shared.contains(item)
    }

    func copy(_ item: SharedItem, to group: String) throws {
        copies += 1
        if refuseCopy.contains(item) {
            throw AppFailure.message("nekad")
        }
        if copyWithoutLanding.contains(item) { return }
        shared.insert(item)
    }

    func delete(_ item: SharedItem, group: String?) throws {
        if group == nil {
            own.remove(item)
            deletions.append(item)
        } else {
            shared.remove(item)
        }
    }
}

final class KeychainMigrationTests: XCTestCase {
    private let group = "TEAM.se.aim.remote.shared"

    func testEverythingMovesToTheSharedGroup() {
        let keychain = FakeKeychain(own: [.clientKey, .clientCertificate, .tvList])
        let report = KeychainMigrator.run(group: group, using: keychain)

        XCTAssertEqual(Set(report.copied), Set(SharedItem.allCases))
        XCTAssertEqual(keychain.shared, Set(SharedItem.allCases))
        XCTAssertTrue(keychain.own.isEmpty, "Originalen tas bort när kopiorna finns.")
        XCTAssertTrue(report.failed.isEmpty)
    }

    func testRunningItTwiceChangesNothingTheSecondTime() {
        let keychain = FakeKeychain(own: [.clientKey, .clientCertificate, .tvList])
        KeychainMigrator.run(group: group, using: keychain)
        let copiesAfterFirst = keychain.copies

        let second = KeychainMigrator.run(group: group, using: keychain)

        XCTAssertEqual(keychain.copies, copiesAfterFirst, "Inget kopieras om.")
        XCTAssertTrue(second.copied.isEmpty)
        XCTAssertEqual(Set(second.alreadyShared), Set(SharedItem.allCases))
        XCTAssertEqual(keychain.shared, Set(SharedItem.allCases))
    }

    func testTheOriginalStaysWhenTheCopyFails() {
        let keychain = FakeKeychain(own: [.clientKey, .clientCertificate, .tvList])
        keychain.refuseCopy = [.clientKey]

        let report = KeychainMigrator.run(group: group, using: keychain)

        XCTAssertEqual(report.failed, [.clientKey])
        XCTAssertTrue(keychain.own.contains(.clientKey), "Nyckeln får inte försvinna.")
        XCTAssertFalse(keychain.shared.contains(.clientKey))
        XCTAssertFalse(keychain.deletions.contains(.clientKey))
        // Resten flyttas ändå.
        XCTAssertTrue(keychain.shared.contains(.clientCertificate))
        XCTAssertTrue(keychain.shared.contains(.tvList))
    }

    func testTheOriginalStaysWhenTheCopyCannotBeVerified() {
        let keychain = FakeKeychain(own: [.tvList])
        keychain.copyWithoutLanding = [.tvList]

        let report = KeychainMigrator.run(group: group, using: keychain)

        XCTAssertEqual(report.failed, [.tvList])
        XCTAssertTrue(keychain.own.contains(.tvList))
        XCTAssertTrue(report.copied.isEmpty, "Utan verifierad kopia räknas inget som flyttat.")
    }

    func testARetryAfterAFailureCompletesTheMove() {
        let keychain = FakeKeychain(own: [.clientKey, .tvList])
        keychain.refuseCopy = [.clientKey]
        KeychainMigrator.run(group: group, using: keychain)
        XCTAssertTrue(keychain.own.contains(.clientKey))

        keychain.refuseCopy = []
        let second = KeychainMigrator.run(group: group, using: keychain)

        XCTAssertEqual(second.copied, [.clientKey])
        XCTAssertTrue(keychain.shared.contains(.clientKey))
        XCTAssertTrue(keychain.own.isEmpty)
    }

    func testNothingToMoveIsReportedAsMissing() {
        let keychain = FakeKeychain(own: [])
        let report = KeychainMigrator.run(group: group, using: keychain)

        XCTAssertEqual(Set(report.missing), Set(SharedItem.allCases))
        XCTAssertTrue(report.copied.isEmpty)
        XCTAssertTrue(report.failed.isEmpty)
    }

    func testAnOrphanedOriginalIsRemovedWhenTheCopyAlreadyExists() {
        let keychain = FakeKeychain(own: [.tvList])
        keychain.shared = [.tvList]

        let report = KeychainMigrator.run(group: group, using: keychain)

        XCTAssertEqual(report.alreadyShared, [.tvList])
        XCTAssertEqual(report.removedOriginals, [.tvList])
        XCTAssertTrue(keychain.own.isEmpty)
        XCTAssertTrue(keychain.shared.contains(.tvList))
    }
}
