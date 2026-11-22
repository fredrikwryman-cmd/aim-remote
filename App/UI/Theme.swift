import SwiftUI

// Designsystemet för Tech Rabbit Remote. Värden ur
// design/referenser/TR-Remote-selection.png och designpaketets tokens.

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

struct Palette {
    var background: Color
    var surface: Color
    var surfaceElevated: Color
    var surfaceGlass: Color
    var surfaceBorder: Color
    var sheet: Color
    var textPrimary: Color
    var textSecondary: Color
    var textMuted: Color
    var accent: Color
    var accentText: Color
    var connectText: Color
    var accentSubtle: Color
    var success: Color
    var danger: Color
    var iconPrimary: Color
    var separator: Color
    var tabInactive: Color
    var glassStops: [Color]
    var glassAngle: Double
    var rockerStops: [Color]
    var rockerAngle: Double
    var panelStops: [Color]
    var powerStops: [Color]
    var tileStops: [Color]
    var buttonShadow: Color
    var buttonShadowRadius: CGFloat
    var buttonShadowY: CGFloat
    var pressTint: Color

    static let light = Palette(
        background: Color(hex: 0xEEF0F2),
        surface: Color(hex: 0xF8F9FA, opacity: 0.72),
        surfaceElevated: .white,
        surfaceGlass: Color(hex: 0xFAFBFC, opacity: 0.92),
        surfaceBorder: .white.opacity(0.95),
        sheet: Color(hex: 0xF4F5F7),
        textPrimary: Color(hex: 0x111417),
        textSecondary: Color(hex: 0x646C75),
        textMuted: Color(hex: 0x7A828B),
        accent: Color(hex: 0x1FB24E),
        accentText: Color(hex: 0x1E9E46),
        connectText: Color(hex: 0x157535),
        accentSubtle: Color(hex: 0x34C759, opacity: 0.14),
        success: Color(hex: 0x1FC05A),
        danger: Color(hex: 0xE8323A),
        iconPrimary: Color(hex: 0x16191C),
        separator: Color(hex: 0x111417, opacity: 0.08),
        tabInactive: Color(hex: 0x646C75),
        glassStops: [.white, Color(hex: 0xF3F4F6)],
        glassAngle: 180,
        rockerStops: [Color(hex: 0xF7F8F9, opacity: 0.9), Color(hex: 0xEEF0F2, opacity: 0.9)],
        rockerAngle: 180,
        panelStops: [Color(hex: 0xF8F9FA, opacity: 0.72), Color(hex: 0xF2F4F5, opacity: 0.60)],
        powerStops: [.white, Color(hex: 0xFBE9EA), Color(hex: 0xF4D6D8)],
        tileStops: [Color(hex: 0xE9FBEA), Color(hex: 0xC9F1CF)],
        buttonShadow: Color(hex: 0x141E28, opacity: 0.10),
        buttonShadowRadius: 9,
        buttonShadowY: 8,
        pressTint: .black.opacity(0.04)
    )

    static let dark = Palette(
        background: Color(hex: 0x071015),
        surface: Color(hex: 0x141C21, opacity: 0.72),
        surfaceElevated: Color(hex: 0x2B353C),
        surfaceGlass: Color(hex: 0x303C44, opacity: 0.55),
        surfaceBorder: .white.opacity(0.10),
        sheet: Color(hex: 0x0D151A),
        textPrimary: Color(hex: 0xF2F5F7),
        textSecondary: Color(hex: 0x9AA5AE),
        textMuted: Color(hex: 0x7C8790),
        accent: Color(hex: 0x2BE36F),
        accentText: Color(hex: 0x3EE57C),
        connectText: Color(hex: 0x3EE57C),
        accentSubtle: Color(hex: 0x2BE36F, opacity: 0.12),
        success: Color(hex: 0x22D160),
        danger: Color(hex: 0xF0284F),
        iconPrimary: Color(hex: 0xF2F5F7),
        separator: .white.opacity(0.09),
        tabInactive: Color(hex: 0x9AA5AE),
        glassStops: [Color(hex: 0x2B353C), Color(hex: 0x1A2329), Color(hex: 0x141C21)],
        glassAngle: 165,
        rockerStops: [Color(hex: 0x27313A), Color(hex: 0x161E24), Color(hex: 0x11181D)],
        rockerAngle: 170,
        panelStops: [
            Color(hex: 0x2E3940, opacity: 0.55),
            Color(hex: 0x141C21, opacity: 0.72),
            Color(hex: 0x0C1317, opacity: 0.80)
        ],
        powerStops: [Color(hex: 0x2A2F35), Color(hex: 0x15191D)],
        tileStops: [Color(hex: 0x1E3A2C), Color(hex: 0x10221A)],
        buttonShadow: .black.opacity(0.45),
        buttonShadowRadius: 10,
        buttonShadowY: 10,
        pressTint: .white.opacity(0.06)
    )

    static func of(_ scheme: ColorScheme) -> Palette { scheme == .dark ? .dark : .light }
}

extension ColorScheme {
    var palette: Palette { Palette.of(self) }
}

// Gradienten ritas i vinkel enligt tokens: 180 rakt nedåt, 165 och 170 snett.
func angledGradient(_ stops: [Color], angle: Double) -> LinearGradient {
    let radians = (angle - 90) * .pi / 180
    let dx = cos(radians) / 2
    let dy = sin(radians) / 2
    return LinearGradient(
        colors: stops,
        startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
        endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
    )
}

// MARK: - Bakgrunder

struct PremiumBackground: View {
    enum Screen { case remote, settings }
    var screen: Screen = .remote
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = scheme.palette
        ZStack {
            if scheme == .dark {
                LinearGradient(
                    colors: [Color(hex: 0x0C171D), Color(hex: 0x071015), Color(hex: 0x050B0F)],
                    startPoint: .topLeading, endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color(hex: 0x1C2C33, opacity: 0.45), Color(hex: 0x1C2C33, opacity: 0)],
                    center: UnitPoint(x: screen == .remote ? 0.85 : 0.2, y: 0.42),
                    startRadius: 0, endRadius: 420
                )
            } else {
                LinearGradient(
                    colors: [Color(hex: 0xF2F3F5), Color(hex: 0xECEEF0)],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [
                        Color(hex: 0x96E2A0, opacity: 0.55),
                        Color(hex: 0xCDEED0, opacity: 0.35),
                        Color(hex: 0xEEF0F2, opacity: 0)
                    ],
                    center: UnitPoint(x: screen == .remote ? 1 : 0.1, y: 0.92),
                    startRadius: 0, endRadius: 360
                )
            }
        }
        .background(palette.background)
        .ignoresSafeArea()
    }
}

// MARK: - Knappar

struct GlassButtonStyle: ButtonStyle {
    var radius: CGFloat = 23.5
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let palette = scheme.palette
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .foregroundStyle(palette.iconPrimary)
            .background(angledGradient(palette.glassStops, angle: palette.glassAngle), in: shape)
            .overlay(shape.fill(configuration.isPressed ? palette.pressTint : Color.clear))
            .overlay(shape.stroke(palette.surfaceBorder, lineWidth: 1))
            .shadow(
                color: isEnabled ? palette.buttonShadow : .clear,
                radius: palette.buttonShadowRadius, y: palette.buttonShadowY
            )
            .opacity(isEnabled ? 1 : 0.38)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: configuration.isPressed ? 0.07 : 0.14), value: configuration.isPressed)
    }
}

// 123, mikrofon, tillbaka och hem: ingen glasyta, bara ikonen.
struct BareButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(scheme.palette.iconPrimary)
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.38)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(.easeOut(duration: configuration.isPressed ? 0.07 : 0.14), value: configuration.isPressed)
    }
}

// MARK: - Ytor

struct CardSurface: ViewModifier {
    var radius: CGFloat = 26
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let palette = scheme.palette
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(palette.surfaceGlass, in: shape)
            .overlay(shape.stroke(palette.surfaceBorder, lineWidth: 1))
            .shadow(
                color: scheme == .dark ? .black.opacity(0.35) : Color(hex: 0x1E2832, opacity: 0.06),
                radius: 16, y: 12
            )
    }
}

struct PanelSurface: ViewModifier {
    var radius: CGFloat = 27
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let palette = scheme.palette
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(angledGradient(palette.panelStops, angle: scheme == .dark ? 165 : 180), in: shape)
            .overlay(shape.stroke(palette.surfaceBorder, lineWidth: 1))
            .shadow(
                color: scheme == .dark ? .black.opacity(0.45) : Color(hex: 0x1E2832, opacity: 0.06),
                radius: scheme == .dark ? 24 : 16,
                y: scheme == .dark ? 24 : 12
            )
    }
}

extension View {
    func cardSurface(radius: CGFloat = 26) -> some View { modifier(CardSurface(radius: radius)) }
    func panelSurface(radius: CGFloat = 27) -> some View { modifier(PanelSurface(radius: radius)) }
}

// Bakåtkompatibelt namn för knappstilen.
typealias RemoteButtonStyle = GlassButtonStyle
