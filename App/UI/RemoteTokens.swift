import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Automatiskt"
        case .light: return "Ljust"
        case .dark: return "Mörkt"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

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

// Tokens ur designpaketets tokens.json (Tech Rabbit Remote v1).
// Referens 390 x 844 pt. Alla mått är fasta pt-värden.

enum TR {

    // MARK: - Färger

    struct Colors {
        var bgTop: Color
        var bgBottom: Color
        var text: Color
        var muted: Color
        var mutedOnHero: Color
        var greenText: Color
        var green: Color
        var panel: Color
        var line: Color
        var divider: Color
        var keyTop: Color
        var keyBottom: Color
        var keyFlat: Color
        var okTop: Color
        var okBottom: Color
        var okBorder: Color
        var power: Color
        var powerBg: Color
        var pill: Color
        var tab: Color
        var tabActive: Color
        var swoosh: Color
        var swooshLine: Color
        var sheetTop: Color
        var sheetBottom: Color
        var scrim: Color
        var keyShadow: Color
        var keyShadowOpacity: Double

        static let dark = Colors(
            bgTop: Color(hex: 0x0A1A0E),
            bgBottom: Color(hex: 0x050C07),
            text: Color(hex: 0xF2F2F2),
            muted: Color(hex: 0x9AA79D),
            mutedOnHero: Color(hex: 0xC9D6CC),
            greenText: Color(hex: 0x1CF038),
            green: Color(hex: 0x1ED63C),
            panel: .white.opacity(0.035),
            line: .white.opacity(0.08),
            divider: .white.opacity(0.07),
            keyTop: Color(hex: 0x1C2A20),
            keyBottom: Color(hex: 0x111A14),
            keyFlat: .white.opacity(0.05),
            okTop: Color(hex: 0x123A1C),
            okBottom: Color(hex: 0x0B2412),
            okBorder: Color(hex: 0x1ED63C),
            power: Color(hex: 0xE5402A),
            powerBg: Color(hex: 0xE5402A, opacity: 0.14),
            pill: Color(hex: 0x1ED63C, opacity: 0.14),
            tab: Color(hex: 0x0C180F, opacity: 0.94),
            tabActive: Color(hex: 0x1ED63C, opacity: 0.14),
            swoosh: Color(hex: 0x1ED63C, opacity: 0.10),
            swooshLine: Color(hex: 0x1CF038, opacity: 0.35),
            sheetTop: Color(hex: 0x28342C, opacity: 0.94),
            sheetBottom: Color(hex: 0x141C17, opacity: 0.96),
            scrim: Color(hex: 0x030804, opacity: 0.5),
            keyShadow: .black,
            keyShadowOpacity: 0.45
        )

        static let light = Colors(
            bgTop: Color(hex: 0xF7F8F7),
            bgBottom: Color(hex: 0xECEFEC),
            text: Color(hex: 0x0B0B0B),
            muted: Color(hex: 0x5A5A5A),
            mutedOnHero: Color(hex: 0x0B0B0B),
            greenText: Color(hex: 0x0A7A1F),
            green: Color(hex: 0x1ED63C),
            panel: .white.opacity(0.6),
            line: .black.opacity(0.06),
            divider: .black.opacity(0.06),
            keyTop: .white,
            keyBottom: Color(hex: 0xF3F5F3),
            keyFlat: .white,
            okTop: Color(hex: 0xF1FDF2),
            okBottom: Color(hex: 0xDFF8DA),
            okBorder: Color(hex: 0x1ED63C),
            power: Color(hex: 0xE5402A),
            powerBg: Color(hex: 0xE5402A, opacity: 0.10),
            pill: Color(hex: 0xDFF8DA),
            tab: .white.opacity(0.85),
            tabActive: Color(hex: 0xDFF8DA),
            swoosh: Color(hex: 0x1ED63C, opacity: 0.10),
            swooshLine: Color(hex: 0x1ED63C, opacity: 0.35),
            sheetTop: .white.opacity(0.94),
            sheetBottom: Color(hex: 0xF3F5F3, opacity: 0.96),
            scrim: .black.opacity(0.35),
            keyShadow: .black,
            keyShadowOpacity: 0.08
        )

        static func of(_ scheme: ColorScheme) -> Colors { scheme == .dark ? .dark : .light }
    }

    enum PrimaryButton {
        static let top = Color(hex: 0x2FD44A)
        static let bottom = Color(hex: 0x13A82E)
        static let border = Color(hex: 0x1CF038, opacity: 0.6)
    }

    // MARK: - Mått (tokens.json size/radius)

    enum Size {
        static let sidePadding: CGFloat = 18
        static let headerRow: CGFloat = 50
        static let powerButton: CGFloat = 50
        static let iconButton: CGFloat = 44
        static let rockerWidth: CGFloat = 70
        static let rockerHeight: CGFloat = 140
        static let smallKey: CGFloat = 52
        static let dpadKeyWidth: CGFloat = 78
        static let dpadKeyHeight: CGFloat = 70
        static let dpadColumn: CGFloat = 82
        static let dpadRow: CGFloat = 72
        // SPEC R02: d-padens rutnät har gap 10 mellan raderna.
        static let dpadGap: CGFloat = 10
        static let okKeyWidth: CGFloat = 82
        static let okKeyHeight: CGFloat = 74
        static let mediaKey: CGFloat = 44
        static let tabBar: CGFloat = 64
        static let tabBarBottom: CGFloat = 30
        static let tabBarSide: CGFloat = 14
        static let pillHeight: CGFloat = 30
        static let splashButton: CGFloat = 64
        static let hitTargetMin: CGFloat = 44
        static let panelPadding: CGFloat = 12
        static let panelGap: CGFloat = 14
        // SPEC R03: inställningskortet har fem rader à 52.
        static let settingsRow: CGFloat = 52
        // SPEC R04: Anslut-knappen är 52 hög, radie 26 (TR.Radius.primaryButton).
        static let primaryButton: CGFloat = 52
        // SPEC R04: raderna i bladet är 56 höga, radie 18 (TR.Radius.sheetRow).
        static let sheetRow: CGFloat = 56
    }

    enum Radius {
        static let panel: CGFloat = 34
        static let rocker: CGFloat = 30
        static let smallKey: CGFloat = 18
        static let dpadKey: CGFloat = 22
        static let okKey: CGFloat = 24
        static let mediaKey: CGFloat = 22
        static let tabBar: CGFloat = 24
        static let tabItem: CGFloat = 18
        static let card: CGFloat = 24
        static let hero: CGFloat = 28
        static let sheet: CGFloat = 34
        static let sheetRow: CGFloat = 18
        static let primaryButton: CGFloat = 26
        static let pill: CGFloat = 15
        static let splashButton: CGFloat = 20
    }

    enum Motion {
        static let press: Double = 0.10
        static let pressScale: CGFloat = 0.96
        static let pressOpacity: Double = 0.9
        static let okPress: Double = 0.12
        static let okPressScale: CGFloat = 0.95
        static let sheetIn: Double = 0.28
        static let sheetOut: Double = 0.20
        static let themeSwap: Double = 0.25
        static let tab: Double = 0.18
    }

    // MARK: - Typsnitt (Archivo 400-900)

    enum Font {
        static func archivo(_ weight: Int, _ size: CGFloat) -> SwiftUI.Font {
            .custom(name(for: weight), fixedSize: size)
        }
        // Etiketter får skala, men högst 1,3 gånger (tokens: Dynamic Type max 1,3).
        static func scaled(_ weight: Int, _ size: CGFloat) -> SwiftUI.Font {
            .custom(name(for: weight), size: size)
        }
        private static func name(for weight: Int) -> String {
            switch weight {
            case ..<500: return "Archivo-Regular"
            case 500..<600: return "Archivo-Medium"
            case 600..<700: return "Archivo-SemiBold"
            case 700..<800: return "Archivo-Bold"
            case 800..<900: return "Archivo-ExtraBold"
            default: return "Archivo-Black"
            }
        }

        static let title = archivo(800, 34)          // R01-rubrik
        static let screenTitle = scaled(800, 24)
        static let device = scaled(700, 20)
        static let heroTitle = scaled(800, 20)
        static let sheetTitle = scaled(800, 20)
        static let ok = archivo(700, 21)             // fast, tangent
        static let row = scaled(500, 15)
        static let rowValue = scaled(400, 14)
        static let body = scaled(400, 17)
        static let status = scaled(600, 14)
        static let caption = scaled(400, 12)
        static let keyLabel = archivo(400, 13)       // fast, tangent
        static let tabLabel = scaled(400, 11)
        static let tabLabelActive = scaled(700, 11)
        static let number = archivo(600, 20)         // "123", fast
    }
}

// Dynamic Type högst 1,3 på etiketter.
struct LimitedDynamicType: ViewModifier {
    func body(content: Content) -> some View {
        content.dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

extension View {
    func trLabelScaling() -> some View { modifier(LimitedDynamicType()) }
}

// MARK: - Haptik enligt tokens.json

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

struct RemoteBackground: View {
    enum Variant { case remote, start }
    var variant: Variant = .remote
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        ZStack {
            LinearGradient(colors: [colors.bgTop, colors.bgBottom], startPoint: .top, endPoint: .bottom)
            Image(variant == .start ? "SwooshStart" : "Swoosh")
                .resizable()
                .scaledToFill()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
