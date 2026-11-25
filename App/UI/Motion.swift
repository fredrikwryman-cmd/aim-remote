import SwiftUI
import UIKit

// Rörelse och haptik på ett ställe, enligt skillen rev-ux avsnitt 3 och 7.
// Filen bestämmer bara beteende: tider, fjädrar och vibrationer. Färger,
// typsnitt, former och mått ligger kvar i RemoteTokens.swift och är
// oförändrade.

enum TRMotion {

    // MARK: - Tider (sekunder)

    /// Tryck ned.
    static let tap: Double = 0.09
    /// Ikonbyte, text, chip, flikbyte.
    static let swap: Double = 0.16
    /// Sidbyte och hero.
    static let push: Double = 0.32
    /// Panel upp eller ned.
    static let sheet: Double = 0.38
    /// Förskjutning mellan delarna i en panel.
    static let stagger: Double = 0.035
    /// Ut går på ungefär 70 % av tiden in tog.
    static let outRatio: Double = 0.70
    /// Panelen ut.
    static let sheetOut: Double = sheet * outRatio
    /// Kort entré när appen kommer tillbaka.
    static let entrance: Double = 0.30
    /// Entrén börjar strax över full storlek.
    static let entranceScale: CGFloat = 1.04
    /// Byte av utseende. Låg på 250 ms före den här filen och ligger kvar där.
    static let theme: Double = 0.25
    /// Tomt läge i Välj TV visas efter den här tiden utan träff.
    static let emptyStateDelay: Double = 8

    // MARK: - Mått som hör till rörelsen

    /// Sidan bakom en öppen panel.
    static let recedeScale: CGFloat = 0.94
    static let recedeDim: Double = 0.45
    /// Allt tryckbart.
    static let pressScale: CGFloat = 0.97

    // MARK: - Fjädrar

    /// Knappar, tangenter, ikoner.
    static let snappy = Animation.interpolatingSpring(mass: 1, stiffness: 340, damping: 24)
    /// Sidor, paneler, scroll-snäpp.
    static let smooth = Animation.interpolatingSpring(mass: 1, stiffness: 220, damping: 28)
    /// Liten överstudsning.
    static let hero = Animation.interpolatingSpring(mass: 1, stiffness: 210, damping: 18)

    /// Reducerad rörelse: förflyttning, skalning och puls blir en
    /// korsövergång på 160 ms (punkt 18). Haptiken ligger kvar.
    static let crossfade = Animation.easeInOut(duration: swap)

    /// Fjädern, eller korsövergången när rörelse är nedtonad.
    static func spring(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
        reduceMotion ? crossfade : animation
    }
}

// MARK: - Haptik

/// Spärren i haptikkartan: aldrig två haptiker inom 80 ms. Ligger utanför
/// TRHaptics för att kunna provas för sig.
struct HapticGate {
    static let minimumInterval: Double = 0.08

    private var last: Double?

    /// Sant när en haptik får spelas vid tidpunkten. Ett nekat anrop flyttar
    /// inte fönstret.
    mutating func allows(at now: Double) -> Bool {
        if let last, now - last < HapticGate.minimumInterval { return false }
        last = now
        return true
    }
}

/// Kartan i punkt 2. Varje haptik i appen går genom TRHaptics.play.
enum TRHaptic {
    /// Fjärrtangenter och vippor, även vid hållrepetition.
    case key
    /// Flikbyte och val i listor.
    case selection
    /// Panel snäpper upp eller ned.
    case soft
    /// Tillståndsbyte på objektet.
    case medium
    /// Ansluten, eller en handling som lyckades.
    case success
    /// Före en oåterkallelig handling.
    case warning
    /// Fel, tappad anslutning, ogiltig kod.
    case error
}

@MainActor
enum TRHaptics {
    /// Raden Knappvibration i Inställningar styr all haptik (punkt 3).
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "tr.remote.haptics") as? Bool ?? true
    }

    private static var gate = HapticGate()

    static func play(_ kind: TRHaptic,
                     at now: Double = ProcessInfo.processInfo.systemUptime) {
        guard isEnabled, gate.allows(at: now) else { return }
        switch kind {
        case .key:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // Namnen nedan är bara genvägar till kartan ovan.
    static func key() { play(.key) }
    static func repeated() { play(.key) }
    static func selection() { play(.selection) }
    static func soft() { play(.soft) }
    static func state() { play(.medium) }
    static func connected() { play(.success) }
    static func warning() { play(.warning) }
    static func error() { play(.error) }
}

// MARK: - Panelen växer ur knappen som öppnade den (punkt 7)

/// Knappens plats på skärmen, läst med en anchor-preference. RemoteRoot
/// räknar om den till den punkt panelen växer ur.
struct PanelOriginKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, next in next }
    }
}

extension View {
    /// Märker knappen som öppnar en panel, så att panelen kan växa ur den.
    func panelSource(_ panel: Panel) -> some View {
        anchorPreference(key: PanelOriginKey.self, value: .bounds) { [panel.id: $0] }
    }
}

// MARK: - Ordning in och ut i en panel (punkt 9)

/// Rubrik först, innehåll med 35 ms förskjutning, stängknapp sist. Ut i
/// omvänd ordning på ungefär 70 % av tiden.
func trStageTransition(_ index: Int, of count: Int, reduceMotion: Bool) -> AnyTransition {
    guard !reduceMotion else {
        return AnyTransition.opacity.animation(TRMotion.crossfade)
    }
    let inDelay = Double(index) * TRMotion.stagger
    let outDelay = Double(max(count - 1 - index, 0)) * TRMotion.stagger
    return .asymmetric(
        insertion: AnyTransition.opacity
            .combined(with: .offset(y: 8))
            .animation(.easeOut(duration: TRMotion.swap).delay(inDelay)),
        removal: AnyTransition.opacity
            .animation(.easeIn(duration: TRMotion.swap * TRMotion.outRatio).delay(outDelay))
    )
}

/// Punkten panelen växer ur, räknad om till panelens egen ruta. GlassSheet
/// läser den här i stället för att varje panel ska skicka den vidare.
private struct PanelOriginKeyEnv: EnvironmentKey {
    static let defaultValue = UnitPoint.center
}

extension EnvironmentValues {
    var panelOrigin: UnitPoint {
        get { self[PanelOriginKeyEnv.self] }
        set { self[PanelOriginKeyEnv.self] = newValue }
    }
}
