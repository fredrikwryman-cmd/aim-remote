import SwiftUI

// Gemensamma komponenter, ritade efter facit (PDF sid 1-2 och sid 5).

// Tangent: gradient keyTop → keyBottom, 1 pt kant och skugga.
// Knappstates enligt sid 5: Standard, Pressed, Disabled.
struct TRKey<Label: View>: View {
    var width: CGFloat?
    var height: CGFloat
    var radius: CGFloat
    var repeats: Bool = false
    var action: () -> Void
    @ViewBuilder var label: Label

    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    @State private var repeater: Timer?

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        label
            .foregroundStyle(colors.textPrimary)
            .frame(width: width, height: height)
            .background(
                LinearGradient(colors: [colors.keyTop, colors.keyBottom],
                               startPoint: .top, endPoint: .bottom),
                in: shape
            )
            .overlay(shape.stroke(colors.line, lineWidth: 1))
            .shadow(color: colors.keyShadow.opacity(colors.keyShadowOpacity), radius: 6, y: 4)
            .scaleEffect(pressed && !reduceMotion ? TR.State.pressedScale : 1)
            .opacity(isEnabled ? (pressed ? TR.State.pressedOpacity : 1) : TR.State.disabledOpacity)
            .animation(.easeOut(duration: TR.Motion.press), value: pressed)
            .contentShape(shape)
            .gesture(press)
            .accessibilityAddTraits(.isButton)
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard isEnabled, !pressed else { return }
                pressed = true
                TRHaptics.key()
                action()
                if repeats { startRepeat() }
            }
            .onEnded { _ in
                pressed = false
                stopRepeat()
            }
    }

    private func startRepeat() {
        repeater?.invalidate()
        // 350 ms fördröjning, sedan var 120 ms.
        repeater = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
            Task { @MainActor in
                repeater = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
                    Task { @MainActor in
                        guard pressed else { return }
                        TRHaptics.repeated()
                        action()
                    }
                }
            }
        }
    }
    private func stopRepeat() {
        repeater?.invalidate()
        repeater = nil
    }
}

// Ikon eller text utan bakgrund (123, mikrofon, tillbaka, hem).
struct TRGhostButton<Label: View>: View {
    var width: CGFloat = TR.Size.hitTargetMin
    var height: CGFloat = TR.Size.hitTargetMin
    var action: () -> Void
    @ViewBuilder var label: Label

    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            TRHaptics.key()
            action()
        } label: {
            label
                .foregroundStyle(TR.Colors.of(scheme).textPrimary)
                .frame(width: max(width, TR.Size.hitTargetMin),
                       height: max(height, TR.Size.hitTargetMin))
                .contentShape(Rectangle())
        }
        .buttonStyle(TRPressStyle())
        .opacity(isEnabled ? 1 : TR.State.disabledOpacity)
    }
}

struct TRPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? TR.State.pressedScale : 1)
            .opacity(configuration.isPressed ? TR.State.pressedOpacity : 1)
            .animation(.easeOut(duration: TR.Motion.press), value: configuration.isPressed)
    }
}

// Vippa: ett kapselformat hölje med två egna tangenter och etiketten emellan.
struct TRRocker: View {
    var title: String
    var upLabel: String
    var downLabel: String
    var width: CGFloat = TR.Size.rockerWidth
    var height: CGFloat = TR.Size.rockerHeight
    var keyHeight: CGFloat = TR.Size.rockerKey
    var inset: CGFloat = TR.Size.rockerInset
    var up: () -> Void
    var down: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: min(TR.Radius.rocker, width / 2),
                                     style: .continuous)
        VStack(spacing: 0) {
            key(icon: "chevron.up", label: upLabel, action: up)
            Spacer(minLength: 0)
            Text(title)
                .font(TR.Font.caption)
                .trLabelScaling()
                .foregroundStyle(colors.textSecondary)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            key(icon: "chevron.down", label: downLabel, action: down)
        }
        .padding(inset)
        .frame(width: width, height: height)
        .background(colors.panel, in: shape)
        .overlay(shape.stroke(colors.line, lineWidth: 1))
        .opacity(isEnabled ? 1 : TR.State.disabledOpacity)
        .accessibilityElement(children: .contain)
    }

    private func key(icon: String, label: String, action: @escaping () -> Void) -> some View {
        TRKey(width: width - inset * 2, height: keyHeight,
              radius: min(TR.Radius.rockerKey, keyHeight / 2),
              repeats: true, action: action) {
            Image(systemName: icon).font(.system(size: 20, weight: .medium))
        }
        .accessibilityLabel(label)
    }
}

// Rund ikonknapp 44. Variant flat (yta + kant) eller ghost.
struct TRIconButton: View {
    enum Variant { case flat, ghost }
    var icon: String
    var variant: Variant = .flat
    var size: CGFloat = TR.Size.iconButton
    var iconSize: CGFloat = 20
    var color: Color?
    var label: String
    var action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(color ?? colors.textPrimary)
                .frame(width: max(size, TR.Size.hitTargetMin),
                       height: max(size, TR.Size.hitTargetMin))
                .background {
                    if variant == .flat {
                        Circle().fill(colors.surfaceElevated)
                            .frame(width: size, height: size)
                            .overlay(Circle().stroke(colors.line, lineWidth: 1)
                                .frame(width: size, height: size))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(TRPressStyle())
        .accessibilityLabel(label)
    }
}

// Flikraden. I ljust läge ett vitt hölje med grön ruta kring valt läge,
// i mörkt läge bara ikon och etikett, som i facit (sid 1 mot sid 2).
struct FloatingTabBar: View {
    @Binding var selection: MainTab
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.tabBar, style: .continuous)
        HStack(spacing: TR.Size.tabItemGap) {
            item(.remote, icon: "appletvremote.gen4", selectedIcon: "appletvremote.gen4.fill",
                 title: "Fjärr")
            item(.settings, icon: "slider.horizontal.3", selectedIcon: "slider.horizontal.3",
                 title: "Inställningar")
        }
        .padding(TR.Size.tabBarPadding)
        .frame(height: TR.Size.tabBar)
        .background {
            if scheme == .light {
                shape.fill(colors.surfaceElevated.opacity(0.92))
                    .overlay(shape.stroke(colors.line, lineWidth: 1))
                    .shadow(color: colors.keyShadow.opacity(0.08), radius: 12, y: 6)
            }
        }
        .padding(.horizontal, TR.Size.sidePadding)
    }

    private func item(_ tab: MainTab, icon: String, selectedIcon: String,
                      title: String) -> some View {
        let colors = TR.Colors.of(scheme)
        let selected = selection == tab
        return Button {
            withAnimation(.easeInOut(duration: TR.Motion.tab)) { selection = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selected ? selectedIcon : icon)
                    .font(.system(size: 22, weight: .regular))
                Text(title)
                    .font(TR.Font.caption)
                    .trLabelScaling()
            }
            .foregroundStyle(selected ? colors.accentText : colors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selected && scheme == .light {
                    RoundedRectangle(cornerRadius: TR.Radius.tabItem, style: .continuous)
                        .fill(colors.accent.opacity(0.18))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Pillret i statusraden. Fylld i ljust läge, konturad i mörkt, som i facit.
struct TRStatusPill: View {
    var title: String
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.pill, style: .continuous)
        Button(action: action) {
            Text(title)
                .font(TR.Font.button)
                .trLabelScaling()
                .foregroundStyle(colors.accentText)
                .padding(.horizontal, 18)
                .frame(height: TR.Size.statusRow)
                .frame(minWidth: TR.Size.hitTargetMin)
                .background(colors.accent.opacity(scheme == .dark ? 0.10 : 0.16), in: shape)
                .overlay {
                    if scheme == .dark {
                        shape.stroke(colors.accent.opacity(0.55), lineWidth: 1)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(TRPressStyle())
    }
}
