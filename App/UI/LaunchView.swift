import SwiftUI

// Kaninloggan. Designpaketet innehåller ingen vektorfil för märket, så det
// är ritat efter startskärmen i design/referenser/TR-Remote-selection.png.
struct RabbitMark: View {
    var size: CGFloat = 120
    var tint: Color = .white
    var accent: Color = Color(hex: 0x1FB24E)

    var body: some View {
        ZStack {
            // Kropp och huvud.
            Ellipse()
                .frame(width: size * 0.52, height: size * 0.44)
                .offset(x: -size * 0.08, y: size * 0.20)
                .rotationEffect(.degrees(-12))
            // Vänster öra.
            Capsule()
                .frame(width: size * 0.15, height: size * 0.54)
                .offset(x: -size * 0.07, y: -size * 0.16)
                .rotationEffect(.degrees(-14))
            // Höger öra.
            Capsule()
                .frame(width: size * 0.15, height: size * 0.50)
                .offset(x: size * 0.14, y: -size * 0.20)
                .rotationEffect(.degrees(14))
        }
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .overlay(alignment: .bottom) {
            // Det gröna bladet nedtill i märket.
            LeafShape()
                .fill(accent)
                .frame(width: size * 0.26, height: size * 0.30)
                .offset(x: size * 0.02, y: -size * 0.10)
        }
        .accessibilityHidden(true)
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.midY)
        )
        path.closeSubpath()
        return path
    }
}

// Startskärmen. Visas kort över fjärren; återanslutningen pågår bakom den.
@MainActor
struct LaunchView: View {
    var onContinue: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let palette = scheme.palette
        ZStack {
            PremiumBackground(screen: .remote)
            VStack(spacing: 0) {
                Spacer()
                RabbitMark(size: 128, tint: palette.textPrimary, accent: palette.accent)
                    .padding(.bottom, 26)
                Text("Tech Rabbit Remote")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(palette.textPrimary)
                Text("Din TV. Din kontroll.")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 8)
                Spacer()
                Button(action: onContinue) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(GlassButtonStyle(radius: 18))
                .accessibilityLabel("Fortsätt till fjärrkontrollen")
                .padding(.bottom, 64)
            }
            .opacity(reduceMotion ? 1 : (shown ? 1 : 0))
            .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.96))
        }
        .onAppear {
            guard !reduceMotion else { shown = true; return }
            withAnimation(.easeOut(duration: 0.35)) { shown = true }
        }
    }
}
