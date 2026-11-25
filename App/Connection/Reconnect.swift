import Foundation

/// Hur länge appen väntar mellan återanslutningsförsöken: 1, 2, 4 och 8
/// sekunder, därefter var tionde så länge appen är framme.
struct ReconnectPolicy: Equatable {
    var steps: [Double]
    var repeating: Double

    init(steps: [Double] = [1, 2, 4, 8], repeating: Double = 10) {
        self.steps = steps
        self.repeating = repeating
    }

    /// `attempt` räknas från 1, alltså första omförsöket efter ett avbrott.
    func delay(forAttempt attempt: Int) -> Double {
        guard attempt >= 1 else { return steps.first ?? repeating }
        guard attempt <= steps.count else { return repeating }
        return steps[attempt - 1]
    }
}

/// Det återanslutningen behöver veta om anslutningen. TVConnection uppfyller
/// det; testerna använder en fejkad anslutning.
@MainActor
protocol ReconnectTarget: AnyObject {
    var isConnected: Bool { get }
    var isConnecting: Bool { get }
    /// Sant när det finns en aktiv sparad TV med pinnat certifikat.
    var hasActiveTV: Bool { get }
    /// Startar en anslutning. Ingen ny parkoppling begärs här.
    func beginConnecting()
}

/// Startar anslutningen när appen kommer fram och försöker igen med backoff om
/// den bryts. Alla omförsök är knutna till att appen är framme: lämnar den
/// skärmen läggs ingen ny tidsinställd kod på kö.
@MainActor
final class ReconnectCoordinator {
    /// Hur ett omförsök läggs på kö. Utbytbar så att testerna kan kalla fram
    /// det själva i stället för att vänta i verklig tid.
    /// Samma mönster som anslutningens egna tidsgränser: en stängning på
    /// huvudkön. MainActor.assumeIsolated finns först i iOS 17 och appen går
    /// ned till 16.4.
    typealias Schedule = (Double, @escaping () -> Void) -> Void

    private weak var target: ReconnectTarget?
    private let policy: ReconnectPolicy
    private let schedule: Schedule
    /// Räknare som gör gamla köade omförsök verkningslösa.
    private var generation = 0
    private var attempt = 0
    private var foreground = false

    init(target: ReconnectTarget,
         policy: ReconnectPolicy = ReconnectPolicy(),
         schedule: Schedule? = nil) {
        self.target = target
        self.policy = policy
        self.schedule = schedule ?? { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    /// Antalet misslyckade försök i följd. Noll när appen just kommit fram
    /// eller när anslutningen står.
    var attemptCount: Int { attempt }

    /// Appen blev aktiv: anslut utan att användaren trycker.
    func appBecameActive() {
        foreground = true
        attempt = 0
        generation += 1
        connectNow()
    }

    /// Appen lämnade förgrunden: inga fler omförsök.
    func appLeftForeground() {
        foreground = false
        generation += 1
    }

    /// Anslutningen står. Backoffen börjar om från 1 s nästa gång.
    func connected() {
        attempt = 0
        generation += 1
    }

    /// Anslutningen föll eller bröts. Nästa försök läggs på kö, men bara så
    /// länge appen är framme och det finns en TV att gå tillbaka till.
    func connectionDropped() {
        guard foreground, let target, target.hasActiveTV else { return }
        attempt += 1
        generation += 1
        let token = generation
        schedule(policy.delay(forAttempt: attempt)) { [weak self] in
            guard let self, self.generation == token, self.foreground else { return }
            self.connectNow()
        }
    }

    private func connectNow() {
        guard foreground, let target else { return }
        guard target.hasActiveTV else { return }
        guard !target.isConnected, !target.isConnecting else { return }
        target.beginConnecting()
    }
}
