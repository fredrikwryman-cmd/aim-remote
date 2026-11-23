import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// Tokens ur facit: PDF:en "Tech Rabbit Remote", sidan 5 (Designsystem).
// Måtten är uppmätta i sidan 1 (Fjärr ljust) och sidan 3 (Inställningar
// ljust), referens 390 x 844 pt. Bilderna ligger i design/referenser/v2/.

enum TR {

    // MARK: - Färger (sid 5)

    struct Colors {
        var background: Color
        var surface: Color
        var surfaceElevated: Color
        var textPrimary: Color
        var textSecondary: Color
        var accent: Color
        var accentText: Color
        var danger: Color

        /// Panelens och kortens yta ligger ovanpå bakgrunden med genomsikt,
        /// så att skenet i nederkanten lyser igenom som i facit.
        var panel: Color
        var line: Color
        var divider: Color
        /// Tangenternas gradient, uppmätt i facit.
        var keyTop: Color
        var keyBottom: Color
        var keyShadow: Color
        var keyShadowOpacity: Double
        var glow: Color
        var scrim: Color
        var sheetTop: Color
        var sheetBottom: Color

        static let light = Colors(
            background: Color(hex: 0xEEF0F2),
            surface: Color(hex: 0xF7F8F9),
            surfaceElevated: Color(hex: 0xFFFFFF),
            textPrimary: Color(hex: 0x111417),
            textSecondary: Color(hex: 0x646C75),
            accent: Color(hex: 0x1FB24E),
            accentText: Color(hex: 0x1E9E46),
            danger: Color(hex: 0xE8323A),
            panel: Color(hex: 0xF7F8F9, opacity: 0.72),
            line: .white.opacity(0.9),
            divider: Color(hex: 0x111417, opacity: 0.07),
            keyTop: Color(hex: 0xFFFFFF),
            keyBottom: Color(hex: 0xF3F4F6),
            keyShadow: Color(hex: 0x111417),
            keyShadowOpacity: 0.10,
            glow: Color(hex: 0x1FB24E, opacity: 0.30),
            scrim: Color(hex: 0x111417, opacity: 0.28),
            sheetTop: Color(hex: 0xFFFFFF, opacity: 0.96),
            sheetBottom: Color(hex: 0xF3F4F6, opacity: 0.97)
        )

        static let dark = Colors(
            background: Color(hex: 0x071015),
            surface: Color(hex: 0x141C21),
            surfaceElevated: Color(hex: 0x2B353C),
            textPrimary: Color(hex: 0xF2F5F7),
            textSecondary: Color(hex: 0x9AA5AE),
            accent: Color(hex: 0x2BE36F),
            accentText: Color(hex: 0x3EE57C),
            danger: Color(hex: 0xF0284F),
            panel: Color(hex: 0x141C21, opacity: 0.72),
            line: .white.opacity(0.07),
            divider: .white.opacity(0.07),
            keyTop: Color(hex: 0x2B353C),
            keyBottom: Color(hex: 0x171F25),
            keyShadow: .black,
            keyShadowOpacity: 0.45,
            glow: Color(hex: 0x2BE36F, opacity: 0.10),
            scrim: .black.opacity(0.5),
            sheetTop: Color(hex: 0x2B353C, opacity: 0.96),
            sheetBottom: Color(hex: 0x141C21, opacity: 0.97)
        )

        static func of(_ scheme: ColorScheme) -> Colors { scheme == .dark ? .dark : .light }
    }

    // MARK: - Mått, uppmätta i facit (390 x 844)

    enum Size {
        static let sidePadding: CGFloat = 15
        static let hitTargetMin: CGFloat = 44

        // Toppkortet
        static let headerCard: CGFloat = 70
        static let headerPadding: CGFloat = 15
        static let powerButton: CGFloat = 50
        static let iconButton: CGFloat = 44

        // Statusraden
        static let statusRow: CGFloat = 33
        static let statusInset: CGFloat = 12
        static let statusDot: CGFloat = 7

        // Fjärrpanelen
        static let panelPaddingH: CGFloat = 11
        static let panelPaddingTop: CGFloat = 16
        static let panelPaddingBottom: CGFloat = 21.5
        static let panelGap: CGFloat = 16
        static let columnGap: CGFloat = 13.5
        static let rockerWidth: CGFloat = 76
        static let rockerHeight: CGFloat = 127
        static let rockerInset: CGFloat = 4
        static let rockerKey: CGFloat = 48
        static let smallKey: CGFloat = 45
        static let smallKeyGap: CGFloat = 28
        static let dpadKey: CGFloat = 84.5
        static let dpadColumnGap: CGFloat = 42
        static let dpadRowGap: CGFloat = 10.5
        static let mediaKey: CGFloat = 49

        /// Panelens höjd i facit: 16 + 127 + 16 + 274,5 + 16 + 49 + 21,5.
        static let panelHeight: CGFloat =
            panelPaddingTop + rockerHeight + panelGap
                + dpadKey * 3 + dpadRowGap * 2 + panelGap + mediaKey + panelPaddingBottom

        // Flikraden
        static let tabBar: CGFloat = 72
        static let tabBarPadding: CGFloat = 8
        static let tabItemGap: CGFloat = 7

        // Inställningar
        static let heroCard: CGFloat = 99
        static let heroIcon: CGFloat = 60
        static let heroPadding: CGFloat = 19
        static let settingsRow: CGFloat = 57
        static let rowPadding: CGFloat = 20

        // Start
        static let splashButton: CGFloat = 64

        // Paneler (blad)
        static let primaryButton: CGFloat = 52
        static let sheetRow: CGFloat = 56
    }

    enum Radius {
        static let headerCard: CGFloat = 35
        static let panel: CGFloat = 34
        static let rocker: CGFloat = 38
        static let rockerKey: CGFloat = 24
        static let smallKey: CGFloat = 22
        static let dpadKey: CGFloat = 26
        static let mediaKey: CGFloat = 24.5
        static let tabBar: CGFloat = 36
        static let tabItem: CGFloat = 28
        static let card: CGFloat = 24
        static let hero: CGFloat = 28
        static let heroIcon: CGFloat = 17
        static let pill: CGFloat = 16.5
        static let sheet: CGFloat = 34
        static let sheetRow: CGFloat = 18
        static let primaryButton: CGFloat = 26
        static let splashButton: CGFloat = 20
    }

    enum Motion {
        static let press: Double = 0.10
        static let pressScale: CGFloat = 0.96
        static let pressOpacity: Double = 0.9
        static let sheetIn: Double = 0.28
        static let sheetOut: Double = 0.20
        static let tab: Double = 0.18
    }

    // MARK: - Typsnitt: SF Pro, systemets (sid 5)

    enum Font {
        /// largeTitle 34 / 41 Bold
        static let largeTitle = SwiftUI.Font.system(size: 34, weight: .bold)
        /// deviceTitle 20 / 24 Semibold
        static let deviceTitle = SwiftUI.Font.system(size: 20, weight: .semibold)
        /// cardTitle 24 / 29 Bold
        static let cardTitle = SwiftUI.Font.system(size: 24, weight: .bold)
        /// body 17 / 22 Regular
        static let body = SwiftUI.Font.system(size: 17, weight: .regular)
        /// button 17 / 22 Medium
        static let button = SwiftUI.Font.system(size: 17, weight: .medium)
        /// numeric 30 / 36 Regular
        static let numeric = SwiftUI.Font.system(size: 30, weight: .regular)
        /// caption 13 / 18 Medium
        static let caption = SwiftUI.Font.system(size: 13, weight: .medium)

        /// Radhöjderna ur sid 5, för text som kan brytas till flera rader.
        static let bodyLineSpacing: CGFloat = 22 - 17
        static let captionLineSpacing: CGFloat = 18 - 13
    }

    /// Knappstates sid 5. Standard, Pressed, Disabled och Selected.
    enum State {
        static let pressedScale: CGFloat = 0.96
        static let pressedOpacity: Double = 0.9
        static let disabledOpacity: Double = 0.4
    }
}

// Dynamic Type högst accessibility1 på etiketter.
struct LimitedDynamicType: ViewModifier {
    func body(content: Content) -> some View {
        content.dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

extension View {
    func trLabelScaling() -> some View { modifier(LimitedDynamicType()) }
}

// MARK: - Haptik

@MainActor
enum TRHaptics {
    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: "tr.remote.haptics") as? Bool ?? true
    }
    static func key() { impact(.light) }
    static func ok() { impact(.medium) }
    static func power() { impact(.heavy) }
    static func repeated() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func connected() { notify(.success) }
    static func error() { notify(.warning) }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Bakgrund

/// Jämn bakgrundsfärg med ett grönt sken i nederkanten, som i facit.
/// Ingen swoosh.
struct RemoteBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        GeometryReader { geometry in
            let h = geometry.size.height
            ZStack {
                colors.background
                // Skenet ligger i nederkanten och klingar av snabbt, som i
                // facit: tydligt i nedre hornen, borta vid panelen.
                glow(colors, at: UnitPoint(x: 0.88, y: 1.06), radius: h * 0.52, strength: 1)
                glow(colors, at: UnitPoint(x: 0.10, y: 1.08), radius: h * 0.30, strength: 0.7)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func glow(_ colors: TR.Colors, at center: UnitPoint,
                      radius: CGFloat, strength: Double) -> some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: colors.glow.opacity(strength), location: 0),
                .init(color: colors.glow.opacity(strength * 0.45), location: 0.30),
                .init(color: colors.glow.opacity(strength * 0.10), location: 0.60),
                .init(color: colors.glow.opacity(0), location: 1)
            ]),
            center: center, startRadius: 0, endRadius: radius
        )
    }
}

// Tech Rabbit-symbolen ur asset-katalogen (SVG med Preserve Vector Data).
struct TRSymbol: View {
    var width: CGFloat
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Image(scheme == .dark ? "TRSymbolDark" : "TRSymbolLight")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityHidden(true)
    }
}
