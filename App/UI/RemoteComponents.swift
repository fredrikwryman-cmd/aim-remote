import SwiftUI

// Gemensamma komponenter för R01/R02 enligt SPEC.md och tokens.json.

// Tangent med gradient keyTop → keyBottom, 1 pt kant i line och skugga.
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
            .foregroundStyle(colors.text)
            .frame(width: width, height: height)
            .frame(minWidth: TR.Size.hitTargetMin, minHeight: TR.Size.hitTargetMin)
            .background(
                LinearGradient(colors: [colors.keyTop, colors.keyBottom], startPoint: .top, endPoint: .bottom),
                in: shape
            )
            .overlay(shape.stroke(colors.line, lineWidth: 1))
            .overlay(
                shape.stroke(.white.opacity(scheme == .dark ? 0.08 : 1), lineWidth: 1)
                    .blendMode(.plusLighter)
                    .opacity(0.6)
                    .mask(shape.fill(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
            )
            .shadow(color: colors.keyShadow.opacity(colors.keyShadowOpacity), radius: 7, y: 6)
            .scaleEffect(pressed && !reduceMotion ? TR.Motion.pressScale : 1)
            .opacity(isEnabled ? (pressed ? TR.Motion.pressOpacity : 1) : 0.4)
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
                fire()
                if repeats { startRepeat() }
            }
            .onEnded { _ in
                pressed = false
                stopRepeat()
            }
    }

    private func fire() {
        TRHaptics.key()
        action()
    }
    private func startRepeat() {
        repeater?.invalidate()
        // 350 ms fördröjning, sedan var 120 ms enligt direktivet §3.
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

// Ikon eller text utan bakgrund (123, mikrofon, tillbaka, hem). Tryckyta minst 44.
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
                .foregroundStyle(TR.Colors.of(scheme).text)
                .frame(width: max(width, TR.Size.hitTargetMin), height: max(height, TR.Size.hitTargetMin))
                .contentShape(Rectangle())
        }
        .buttonStyle(TRPressStyle())
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct TRPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? TR.Motion.pressScale : 1)
            .opacity(configuration.isPressed ? TR.Motion.pressOpacity : 1)
            .animation(.easeOut(duration: TR.Motion.press), value: configuration.isPressed)
    }
}

// OK-tangenten: 82 x 74, kant 2 i #1ED63C, gradient okTop → okBottom, glöd.
struct TROkKey: View {
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.okKey, style: .continuous)
        Button {
            TRHaptics.ok()
            action()
        } label: {
            Text("OK")
                .font(TR.Font.ok)
                .foregroundStyle(colors.text)
                .frame(width: TR.Size.okKeyWidth, height: TR.Size.okKeyHeight)
                .background(
                    LinearGradient(colors: [colors.okTop, colors.okBottom], startPoint: .top, endPoint: .bottom),
                    in: shape
                )
                .overlay(shape.stroke(colors.okBorder, lineWidth: 2))
                .shadow(color: colors.green.opacity(pressed ? 0.75 : 0.45), radius: 11)
                .contentShape(shape)
        }
        .buttonStyle(TROkPressStyle(pressed: $pressed))
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel("Bekräfta")
    }
}

private struct TROkPressStyle: ButtonStyle {
    @Binding var pressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? TR.Motion.okPressScale : 1)
            .animation(.easeOut(duration: TR.Motion.okPress), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { value in pressed = value }
    }
}

// Vippa 70 x 140 med två tryckzoner och etikett i mitten.
struct TRRocker: View {
    var title: String
    var upLabel: String
    var downLabel: String
    var up: () -> Void
    var down: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.rocker, style: .continuous)
        VStack(spacing: 0) {
            zone(icon: "chevron.up", label: upLabel, action: up)
            Text(title)
                .font(TR.Font.keyLabel)
                .foregroundStyle(colors.muted)
                .frame(height: 24)
                .accessibilityHidden(true)
            zone(icon: "chevron.down", label: downLabel, action: down)
        }
        .frame(width: TR.Size.rockerWidth, height: TR.Size.rockerHeight)
        .background(
            LinearGradient(colors: [colors.keyTop, colors.keyBottom], startPoint: .top, endPoint: .bottom),
            in: shape
        )
        .overlay(shape.stroke(colors.line, lineWidth: 1))
        .shadow(color: colors.keyShadow.opacity(colors.keyShadowOpacity), radius: 7, y: 6)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityElement(children: .contain)
    }

    private func zone(icon: String, label: String, action: @escaping () -> Void) -> some View {
        TRRepeatZone(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .frame(width: TR.Size.rockerWidth, height: (TR.Size.rockerHeight - 24) / 2)
        }
        .accessibilityLabel(label)
    }
}

// Tryckzon som upprepar kommandot var 120 ms efter 350 ms nedhållning.
struct TRRepeatZone<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    @State private var repeater: Timer?

    var body: some View {
        content
            .contentShape(Rectangle())
            .opacity(pressed ? TR.Motion.pressOpacity : 1)
            .scaleEffect(pressed && !reduceMotion ? TR.Motion.pressScale : 1)
            .animation(.easeOut(duration: TR.Motion.press), value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !pressed else { return }
                        pressed = true
                        TRHaptics.key()
                        action()
                        start()
                    }
                    .onEnded { _ in
                        pressed = false
                        stop()
                    }
            )
            .accessibilityAddTraits(.isButton)
    }

    private func start() {
        repeater?.invalidate()
        repeater = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
            Task { @MainActor in
                guard pressed else { return }
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
    private func stop() {
        repeater?.invalidate()
        repeater = nil
    }
}

// Rund ikonknapp 44, variant flat (keyFlat + kant) eller ghost.
struct TRIconButton: View {
    enum Variant { case flat, ghost }
    var icon: String
    var variant: Variant = .flat
    var label: String
    var action: () -> Void
    var longPress: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(colors.text)
                .frame(width: TR.Size.iconButton, height: TR.Size.iconButton)
                .background {
                    if variant == .flat {
                        Circle().fill(colors.keyFlat).overlay(Circle().stroke(colors.line, lineWidth: 1))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(TRPressStyle())
        .accessibilityLabel(label)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in longPress?() }
        )
    }
}

// Svävande flikrad. Bara Fjärr och Inställningar i 7A.
struct FloatingTabBar: View {
    @Binding var selection: MainTab
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        HStack(spacing: 0) {
            item(.remote, icon: "appletvremote.gen4.fill", title: "Fjärr")
            item(.settings, icon: "slider.horizontal.3", title: "Inställningar")
        }
        .padding(5)
        .frame(height: TR.Size.tabBar)
        .background(
            RoundedRectangle(cornerRadius: TR.Radius.tabBar, style: .continuous).fill(colors.tab)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TR.Radius.tabBar, style: .continuous).stroke(colors.line, lineWidth: 1)
        )
        .padding(.horizontal, TR.Size.tabBarSide)
    }

    private func item(_ tab: MainTab, icon: String, title: String) -> some View {
        let colors = TR.Colors.of(scheme)
        let selected = selection == tab
        return Button {
            withAnimation(.easeInOut(duration: TR.Motion.tab)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(selected ? TR.Font.tabLabelActive : TR.Font.tabLabel)
                    .trLabelScaling()
            }
            .foregroundStyle(selected ? colors.greenText : colors.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: TR.Radius.tabItem, style: .continuous).fill(colors.tabActive)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Pill i statusraden: höjd 30, radie 15.
struct TRStatusPill: View {
    var title: String
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        Button(action: action) {
            Text(title)
                .font(TR.Font.status)
                .trLabelScaling()
                .foregroundStyle(colors.greenText)
                .padding(.horizontal, 16)
                .frame(height: TR.Size.pillHeight)
                .background(colors.pill, in: RoundedRectangle(cornerRadius: TR.Radius.pill, style: .continuous))
        }
        .buttonStyle(TRPressStyle())
    }
}
