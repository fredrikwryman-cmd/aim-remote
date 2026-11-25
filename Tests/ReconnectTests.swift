import XCTest
@testable import AiMRemote

/// Fejkad anslutning: räknar anropen i stället för att prata med en TV.
@MainActor
private final class FakeConnection: ReconnectTarget {
    var isConnected = false
    var isConnecting = false
    var hasActiveTV = true
    var connectCalls = 0

    func beginConnecting() {
        connectCalls += 1
        isConnecting = true
    }

    /// Anslutningen gick igenom.
    func succeed() {
        isConnecting = false
        isConnected = true
    }

    /// Anslutningen föll.
    func drop() {
        isConnecting = false
        isConnected = false
    }
}

/// Kö som inte väntar i verklig tid: fördröjningarna sparas och körs för hand.
@MainActor
private final class FakeClock {
    var delays: [Double] = []
    private var work: [() -> Void] = []

    func schedule(_ delay: Double, _ block: @escaping () -> Void) {
        delays.append(delay)
        work.append(block)
    }

    /// Kör det senast köade försöket.
    func fireLast() {
        guard let last = work.popLast() else { return XCTFail("Inget forsok ar kolagt..") }
        last()
    }
}

@MainActor
final class ReconnectTests: XCTestCase {

    // MARK: - Fördröjningarna

    func testBackoffStepsThenEveryTenthSecond() {
        let policy = ReconnectPolicy()
        XCTAssertEqual(policy.delay(forAttempt: 1), 1)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2)
        XCTAssertEqual(policy.delay(forAttempt: 3), 4)
        XCTAssertEqual(policy.delay(forAttempt: 4), 8)
        XCTAssertEqual(policy.delay(forAttempt: 5), 10)
        XCTAssertEqual(policy.delay(forAttempt: 99), 10)
    }

    // MARK: - Anslutning vid .active

    func testBecomingActiveStartsConnecting() {
        let (tv, _, coordinator) = made()
        coordinator.appBecameActive()
        XCTAssertEqual(tv.connectCalls, 1, "Appen ska ansluta av sig sjalv nar den blir aktiv.")
    }

    func testBecomingActiveDoesNothingWhenAlreadyConnected() {
        let (tv, _, coordinator) = made()
        tv.isConnected = true
        coordinator.appBecameActive()
        XCTAssertEqual(tv.connectCalls, 0)
    }

    func testBecomingActiveDoesNothingWhileConnecting() {
        let (tv, _, coordinator) = made()
        tv.isConnecting = true
        coordinator.appBecameActive()
        XCTAssertEqual(tv.connectCalls, 0)
    }

    func testNoConnectWithoutASavedTV() {
        let (tv, _, coordinator) = made()
        tv.hasActiveTV = false
        coordinator.appBecameActive()
        XCTAssertEqual(tv.connectCalls, 0, "Utan sparad TV ska ingen anslutning startas.")
    }

    // MARK: - Omförsök

    func testDroppedConnectionRetriesWithGrowingDelays() {
        let (tv, clock, coordinator) = made()
        coordinator.appBecameActive()
        XCTAssertEqual(tv.connectCalls, 1)

        for expected in [1.0, 2.0, 4.0, 8.0, 10.0] {
            tv.drop()
            coordinator.connectionDropped()
            XCTAssertEqual(clock.delays.last, expected)
            clock.fireLast()
        }
        XCTAssertEqual(tv.connectCalls, 6)
        XCTAssertEqual(clock.delays, [1, 2, 4, 8, 10])
    }

    func testSuccessResetsTheBackoff() {
        let (tv, clock, coordinator) = made()
        coordinator.appBecameActive()
        tv.drop(); coordinator.connectionDropped(); clock.fireLast()
        tv.drop(); coordinator.connectionDropped(); clock.fireLast()
        XCTAssertEqual(clock.delays, [1, 2])

        tv.succeed()
        coordinator.connected()
        tv.drop()
        coordinator.connectionDropped()
        XCTAssertEqual(clock.delays.last, 1, "Efter en lyckad anslutning borjar backoffen om.")
    }

    // MARK: - Bakgrunden

    func testLeavingForegroundStopsNewRetries() {
        let (tv, clock, coordinator) = made()
        coordinator.appBecameActive()
        coordinator.appLeftForeground()
        tv.drop()
        coordinator.connectionDropped()
        XCTAssertTrue(clock.delays.isEmpty, "Inga omforsok ska laggas pa ko i bakgrunden.")
    }

    func testQueuedRetryIsDroppedWhenAppLeavesForeground() {
        let (tv, clock, coordinator) = made()
        coordinator.appBecameActive()
        tv.drop()
        coordinator.connectionDropped()
        XCTAssertEqual(clock.delays, [1])

        coordinator.appLeftForeground()
        clock.fireLast()
        XCTAssertEqual(tv.connectCalls, 1, "Ett redan kolagt forsok ska inte sla till i bakgrunden.")
    }

    func testReturningToForegroundConnectsAgain() {
        let (tv, _, coordinator) = made()
        coordinator.appBecameActive()
        tv.drop()
        coordinator.appLeftForeground()
        coordinator.appBecameActive()
        XCTAssertEqual(tv.connectCalls, 2)
        XCTAssertEqual(coordinator.attemptCount, 0)
    }

    // MARK: -

    private func made() -> (FakeConnection, FakeClock, ReconnectCoordinator) {
        let tv = FakeConnection()
        let clock = FakeClock()
        let coordinator = ReconnectCoordinator(
            target: tv,
            schedule: { delay, work in clock.schedule(delay, work) }
        )
        // Testet äger både den fejkade anslutningen och klockan: koordinatoren
        // håller bara en svag referens till målet.
        keepAlive.append(tv)
        keepAlive.append(clock)
        return (tv, clock, coordinator)
    }

    private var keepAlive: [AnyObject] = []
}
