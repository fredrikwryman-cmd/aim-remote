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

    /// Facit ritar fjärren olika i ljust och mörkt läge. Sid 1 har toppkort,
    /// delad vippa och en panel som fyller innerbredden. Sid 2 har inget
    /// toppkort, en vippa i ett stycke och smalare rader. Värdena nedan är
    /// uppmätta i respektive sida; Inställningar (sid 3 och sid 4) är lika.
    struct Layout {
        // Skärmen
        var sidePadding: CGFloat
        var topPadding: CGFloat

        // Toppkortet
        var headerFilled: Bool
        var headerHeight: CGFloat
        var headerPadding: CGFloat
        var powerButton: CGFloat
        var powerIcon: CGFloat
        var headerTextGap: CGFloat
        var displayIcon: CGFloat

        // Statusraden
        var gapHeaderStatus: CGFloat
        var statusRow: CGFloat
        var statusInset: CGFloat
        var gapStatusPanel: CGFloat

        // Panelen
        var panelPaddingH: CGFloat
        var panelPaddingTop: CGFloat
        var panelPaddingBottom: CGFloat
        var gapRockerDpad: CGFloat
        var gapDpadMedia: CGFloat

        // Rad 1
        var rockerSplit: Bool          // sid 1: hölje med två tangenter
        var rockerWidth: CGFloat
        var rockerHeight: CGFloat
        var rockerKey: CGFloat         // bara när rockerSplit
        var rockerInset: CGFloat
        var columnGap: CGFloat
        var smallKey: CGFloat
        var smallKeyGap: CGFloat

        // Rad 2, d-paden
        var dpadKey: CGFloat
        var dpadColumnGap: CGFloat
        var dpadRow: CGFloat
        var dpadRowGap: CGFloat

        // Rad 3, media
        var mediaWidth: CGFloat
        var mediaHeight: CGFloat
        var mediaGap: CGFloat

        /// Innerbredden i facit, som de fasta bredderna är mätta mot.
        var referenceInner: CGFloat

        /// Panelens höjd i facit.
        var panelHeight: CGFloat {
            panelPaddingTop + rockerHeight + gapRockerDpad
                + dpadRow * 3 + dpadRowGap * 2
                + gapDpadMedia + mediaHeight + panelPaddingBottom
        }

        // Facit sid 1: panel 15..375,5 och 185..704,5.
        static let light = Layout(
            sidePadding: 15,
            topPadding: 15,
            headerFilled: true,
            headerHeight: 70,
            headerPadding: 15,
            powerButton: 50,
            powerIcon: 24,
            headerTextGap: 19,
            displayIcon: 27,
            gapHeaderStatus: 7,
            statusRow: 33,
            statusInset: 12,
            gapStatusPanel: 13,
            panelPaddingH: 11,
            panelPaddingTop: 16,
            panelPaddingBottom: 21.5,
            gapRockerDpad: 16,
            gapDpadMedia: 16,
            rockerSplit: true,
            rockerWidth: 76,
            rockerHeight: 127,
            rockerKey: 48,
            rockerInset: 4,
            columnGap: 13.5,
            smallKey: 45,
            smallKeyGap: 28,
            dpadKey: 84.5,
            dpadColumnGap: 42,
            dpadRow: 84.5,
            dpadRowGap: 10.5,
            mediaWidth: 74.5,
            mediaHeight: 49,
            mediaGap: 13.5,
            referenceInner: 338.5
        )

        // Facit sid 2: panel 11..379,5 och 169..724,5, inget toppkort.
        static let dark = Layout(
            sidePadding: 11,
            topPadding: 10,
            headerFilled: false,
            headerHeight: 54,
            headerPadding: 11.5,
            powerButton: 54,
            powerIcon: 26,
            headerTextGap: 13.5,
            displayIcon: 31,
            gapHeaderStatus: 14,
            statusRow: 33,
            statusInset: 12,
            gapStatusPanel: 11,
            panelPaddingH: 17.5,
            panelPaddingTop: 22.5,
            panelPaddingBottom: 33,
            gapRockerDpad: 23.5,
            gapDpadMedia: 22,
            rockerSplit: false,
            rockerWidth: 74,
            rockerHeight: 129,
            rockerKey: 0,
            rockerInset: 0,
            columnGap: 15,
            smallKey: 45.5,
            smallKeyGap: 30,
            dpadKey: 88,
            dpadColumnGap: 30.5,
            dpadRow: 83,
            dpadRowGap: 15,
            mediaWidth: 71,
            mediaHeight: 46,
            mediaGap: 13.5,
            referenceInner: 333.5
        )

        static func of(_ scheme: ColorScheme) -> Layout { scheme == .dark ? .dark : .light }
    }

    /// Mått som är lika i båda lägena.
    enum Size {
        static let hitTargetMin: CGFloat = 44
        static let iconButton: CGFloat = 44
        static let statusDot: CGFloat = 7

        // Flikraden
        static let tabBar: CGFloat = 72
        static let tabBarPadding: CGFloat = 8
        static let tabItemGap: CGFloat = 7

        // Inställningar: sid 3 och sid 4 har samma mått.
        static let sidePadding: CGFloat = 15
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
