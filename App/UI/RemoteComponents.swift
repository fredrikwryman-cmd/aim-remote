import SwiftUI

// Gemensamma komponenter, ritade efter facit (PDF sid 1-2 och sid 5).

// Tangent: gradient keyTop → keyBottom, 1 pt kant och skugga.
// Knappstates enligt sid 5: Standard, Pressed, Disabled.
struct TRKey<Label: View>: View {
    var width: CGFloat?
    var height: CGFloat
    var radius: CGFloat
    var repeats: Bool = false
    /// Facit ritar fjärrens tangenter i full styrka även utan ansluten TV.
    /// Spärren sitter kvar, nedtoningen gör den inte.
    var dims: Bool = true
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
            .scaleEffect(pressed && !reduceMotion ? TRMotion.pressScale : 1)
            .opacity(opacity)
            .animation(TRMotion.spring(reduceMotion, TRMotion.snappy), value: pressed)
            .contentShape(shape)
            .gesture(press)
            .accessibilityAddTraits(.isButton)
    }

    private var opacity: Double {
        if pressed { return TR.State.pressedOpacity }
        return isEnabled || !dims ? 1 : TR.State.disabledOpacity
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
    var dims: Bool = true
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
        .opacity(isEnabled || !dims ? 1 : TR.State.disabledOpacity)
    }
}

struct TRPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? TRMotion.pressScale : 1)
            .opacity(configuration.isPressed ? TR.State.pressedOpacity : 1)
            .animation(TRMotion.spring(reduceMotion, TRMotion.snappy),
                       value: configuration.isPressed)
    }
}

// Vippa. Facit sid 1 ritar ett kapselformat hölje med två egna tangenter;
// sid 2 ritar en enda kapsel med två tryckzoner. Båda finns här.
struct TRRocker: View {
    var title: String
    var upLabel: String
    var downLabel: String
    var width: CGFloat
    var height: CGFloat
    var split: Bool
    var keyHeight: CGFloat
    var inset: CGFloat
    var up: () -> Void
    var down: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: width / 2, style: .continuous)
        return Group {
            if split {
                VStack(spacing: 0) {
                    innerKey(icon: "chevron.up", label: upLabel, action: up)
                    Spacer(minLength: 0)
                    label(colors)
                    Spacer(minLength: 0)
                    innerKey(icon: "chevron.down", label: downLabel, action: down)
                }
                .padding(inset)
                .frame(width: width, height: height)
                .background(colors.panel, in: shape)
                .overlay(shape.stroke(colors.line, lineWidth: 1))
            } else {
                VStack(spacing: 0) {
                    zone(icon: "chevron.up", label: upLabel, action: up)
                    label(colors)
                    zone(icon: "chevron.down", label: downLabel, action: down)
                }
                .frame(width: width, height: height)
                .background(
                    LinearGradient(colors: [colors.keyTop, colors.keyBottom],
                                   startPoint: .top, endPoint: .bottom),
                    in: shape
                )
                .overlay(shape.stroke(colors.line, lineWidth: 1))
                .shadow(color: colors.keyShadow.opacity(colors.keyShadowOpacity), radius: 6, y: 4)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func label(_ colors: TR.Colors) -> some View {
        Text(title)
            .font(TR.Font.caption)
            .trLabelScaling()
            .foregroundStyle(colors.textSecondary)
            .accessibilityHidden(true)
    }

    private func innerKey(icon: String, label: String,
                          action: @escaping () -> Void) -> some View {
        TRKey(width: width - inset * 2, height: keyHeight,
              radius: min(TR.Radius.rockerKey, keyHeight / 2),
              repeats: true, dims: false, action: action) {
            Image(systemName: icon).font(.system(size: 20, weight: .medium))
        }
        .accessibilityLabel(label)
    }

    private func zone(icon: String, label: String,
                      action: @escaping () -> Void) -> some View {
        TRRepeatZone(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(TR.Colors.of(scheme).textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel(label)
    }
}

/// Tryckzon i en vippa som ritas i ett stycke. Upprepar efter 350 ms.
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
            .opacity(pressed ? TR.State.pressedOpacity : 1)
            .scaleEffect(pressed && !reduceMotion ? TRMotion.pressScale : 1)
            .animation(TRMotion.spring(reduceMotion, TRMotion.snappy), value: pressed)
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
            guard selection != tab else { return }
            TRHaptics.selection()
            withAnimation(.easeInOut(duration: TRMotion.swap)) { selection = tab }
        } label: {
            VStack(spacing: 4) {
                TabIcon(name: selected ? selectedIcon : icon, selected: selected)
                Text(title)
                    .font(TR.Font.caption)
                    .trLabelScaling()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
        .buttonStyle(TRPressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Pillret i statusraden. Fylld i ljust läge, konturad i mörkt, som i facit.
struct TRStatusPill: View {
    var title: String
    var height: CGFloat = 33
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.pill, style: .continuous)
        Button(action: action) {
            Text(title)
                .font(TR.Font.button)
                .trLabelScaling()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(colors.accentText)
                .id(title)
                .transition(.opacity)
                .padding(.horizontal, 18)
                .frame(height: height)
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
        .animation(TRMotion.spring(reduceMotion, TRMotion.smooth), value: title)
    }
}

// TV-ikonen i facit: en konturad skarm med fot. SF-symbolen "tv" ritas med
// fylld skarm, darfor ritas glyfen har i stallet.
struct TRDisplayIcon: View {
    var width: CGFloat
    var color: Color

    var body: some View {
        let screen = width * 0.74
        let stroke = max(width * 0.082, 1.4)
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: width * 0.15, style: .continuous)
                .stroke(color, lineWidth: stroke)
                .frame(width: width, height: screen)
            Rectangle()
                .fill(color)
                .frame(width: stroke, height: width * 0.10)
            RoundedRectangle(cornerRadius: stroke / 2, style: .continuous)
                .fill(color)
                .frame(width: width * 0.38, height: stroke)
        }
        .frame(width: width, height: screen + width * 0.10 + stroke)
        .accessibilityHidden(true)
    }
}

// Flikens ikon studsar lätt när fliken väljs (punkt 15). Vid reducerad
// rörelse står den stilla.
private struct TabIcon: View {
    var name: String
    var selected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 22, weight: .regular))
            .scaleEffect(scale)
            .onChange(of: selected) { on in
                guard on, !reduceMotion else { return }
                withAnimation(.easeOut(duration: TRMotion.tap)) { scale = 1.16 }
                withAnimation(TRMotion.hero.delay(TRMotion.tap)) { scale = 1 }
            }
    }
}

// Laddningsskelett i stället för snurra (punkt 11). Raden har samma form och
// höjd som en TV-rad och skimrar lugnt tills de första TV:arna dyker upp.
struct TRSkeletonRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shift: CGFloat = -1

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.sheetRow, style: .continuous)
        HStack(spacing: 14) {
            Circle()
                .fill(colors.textSecondary.opacity(0.18))
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 7) {
                bar(width: 148, height: 12)
                bar(width: 86, height: 10)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .frame(height: TR.Size.sheetRow)
        .background(shape.fill(colors.textSecondary.opacity(0.07)))
        .overlay {
            if !reduceMotion {
                LinearGradient(
                    colors: [.clear, colors.textPrimary.opacity(0.07), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 180)
                .offset(x: shift * 260)
            }
        }
        .clipShape(shape)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                shift = 1
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(TR.Colors.of(scheme).textSecondary.opacity(0.18))
            .frame(width: width, height: height)
    }
}

// Bekräftelseark före en oåterkallelig handling (punkt 14). Konsekvensen
// står i klartext, och den oåterkalleliga knappen ligger sist och markerad.
// Haptik warning när arket öppnas.
@MainActor
struct TRConfirmSheet: View {
    var title: String
    var message: String
    var confirmTitle: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.sheet, style: .continuous)
        ZStack(alignment: .bottom) {
            colors.scrim
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(TR.Font.deviceTitle)
                    .trLabelScaling()
                    .foregroundStyle(colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(TR.Font.body)
                    .foregroundStyle(colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onCancel) {
                    Text("Avbryt")
                        .font(TR.Font.button)
                        .foregroundStyle(colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: TR.Size.primaryButton)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TRPressStyle())
                .padding(.top, 2)

                // Sist och markerad.
                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(TR.Font.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: TR.Size.primaryButton)
                        .background(
                            colors.danger,
                            in: RoundedRectangle(cornerRadius: TR.Radius.primaryButton,
                                                 style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(TRPressStyle())
                .accessibilityLabel(confirmTitle)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [colors.sheetTop, colors.sheetBottom],
                               startPoint: .top, endPoint: .bottom),
                in: shape
            )
            .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear { TRHaptics.warning() }
    }
}
