import SwiftUI
import AiMCore

// R02 Fjärr. Fasta pt-mått enligt SPEC.md steg 1-4 (referens 390 x 844).
@MainActor
struct RemoteScreen: View {
    @ObservedObject var connection: TVConnection
    @Binding var appearanceRaw: String
    var openPanel: (Panel) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var toast: String?

    /// Panelens mått vid den bredd och höjd som faktiskt finns. Proportionerna
    /// är SPEC:ens; bara skalan ändras, så att tangenter och mellanrum växer
    /// med skärmen i stället för att lämna ett tomt fält under panelen.
    private struct PanelMetrics {
        var width: CGFloat
        var gap: CGFloat
        var keyGap: CGFloat
        var rocker: CGFloat
        var smallKey: CGFloat
        var dpadRow: CGFloat
        var okKey: CGFloat
        var media: CGFloat
        var height: CGFloat
    }

    /// SPEC R02: 12 + 140 + 14 + (3 x 72 med gap 10) + 14 + 44 + 12 = 472.
    private static let basePanelHeight: CGFloat =
        TR.Size.panelPadding * 2 + TR.Size.rockerHeight + TR.Size.panelGap
            + TR.Size.dpadRow * 3 + TR.Size.dpadGap * 2 + TR.Size.panelGap + TR.Size.mediaKey

    private func metrics(width: CGFloat, height: CGFloat) -> PanelMetrics {
        // Facit ritar panelen i fasta pt-mått. Den växer aldrig över SPEC:ens
        // storlekar; blir det höjd över ligger den under panelen, som i facit.
        // Krymper bara på skärmar som är för korta, och aldrig under 0,82:
        // då blir mediatangenten mindre än träffytan.
        let scale = min(1.0, max(0.82, height / Self.basePanelHeight))
        let gap = TR.Size.panelGap * scale
        let rocker = TR.Size.rockerHeight * scale
        let dpadRow = TR.Size.dpadRow * scale
        let media = max(TR.Size.mediaKey * scale, TR.Size.hitTargetMin)
        return PanelMetrics(
            width: width,
            gap: gap,
            keyGap: 10 * scale,
            rocker: rocker,
            smallKey: TR.Size.smallKey * scale,
            dpadRow: dpadRow,
            okKey: TR.Size.okKeyHeight * scale,
            media: media,
            height: TR.Size.panelPadding * 2 + rocker + gap + dpadRow * 3
                + TR.Size.dpadGap * 2 * scale + gap + media
        )
    }

    var body: some View {
        GeometryReader { geometry in
            // Flikraden är redan avdragen av RemoteRoot, så hela höjden här
            // tillhör fjärren.
            let above = TR.Size.headerRow + 14 + TR.Size.pillHeight + 16
            let m = metrics(width: geometry.size.width - TR.Size.sidePadding * 2,
                            height: max(geometry.size.height - above, 1))
            VStack(alignment: .leading, spacing: 0) {
                header
                statusRow.padding(.top, 14)
                panel(m)
                    .padding(.top, 16)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, TR.Size.sidePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(TR.Font.status)
                        .foregroundStyle(TR.Colors.of(scheme).text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(TR.Colors.of(scheme).tab, in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - 1. Huvud, rad 50

    private var header: some View {
        let colors = TR.Colors.of(scheme)
        return HStack(spacing: 0) {
            Button {
                TRHaptics.power()
                connection.press(.power)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(colors.power)
                    .frame(width: TR.Size.powerButton, height: TR.Size.powerButton)
                    .background(Circle().fill(colors.powerBg))
                    .contentShape(Circle())
            }
            .buttonStyle(TRPressStyle())
            .accessibilityLabel("Slå på eller av TV:n")

            VStack(alignment: .leading, spacing: 0) {
                Text(connection.tvName)
                    .font(TR.Font.device)
                    .trLabelScaling()
                    .foregroundStyle(colors.text)
                    .lineLimit(1)
                Text("Tech Rabbit Remote")
                    .font(TR.Font.caption)
                    .trLabelScaling()
                    .foregroundStyle(colors.muted)
            }
            .padding(.leading, 12)

            Spacer(minLength: 8)

            TRIconButton(
                icon: themeScheme == .dark ? "sun.max" : "moon",
                variant: .flat,
                label: themeScheme == .dark ? "Byt till ljust utseende" : "Byt till mörkt utseende",
                action: toggleTheme,
                longPress: useSystemTheme,
                diagnosticValue: appearanceRaw
            )
            TRIconButton(icon: "tv", variant: .ghost, label: "Välj TV") {
                openPanel(.chooseTV)
            }
            .padding(.leading, 4)
        }
        .frame(height: TR.Size.headerRow)
    }

    // MARK: - 2. Statusrad

    private var statusRow: some View {
        let colors = TR.Colors.of(scheme)
        return HStack(spacing: 8) {
            StatusDot(state: state)
            Text(state.text)
                .font(TR.Font.status)
                .trLabelScaling()
                .foregroundStyle(state.textColor(colors))
            Spacer(minLength: 8)
            TRStatusPill(title: state.pill) {
                switch state {
                case .connected: connection.disconnect()
                default: openPanel(.chooseTV)
                }
            }
            .accessibilityLabel(state.pill)
        }
        .frame(height: TR.Size.pillHeight)
    }

    private var state: RemoteState {
        if connection.notice != nil && !connection.ready { return .failed }
        if connection.busy { return .connecting }
        return connection.ready ? .connected : .disconnected
    }

    // MARK: - 3. Fjärrpanel

    private func panel(_ m: PanelMetrics) -> some View {
        let colors = TR.Colors.of(scheme)
        let inner = m.width - TR.Size.panelPadding * 2
        let middle = inner - TR.Size.rockerWidth * 2 - 20
        let smallKeyWidth = (middle - 10) / 2
        let mediaWidth = (inner - 24) / 4

        return VStack(spacing: m.gap) {
            // Övre rad: vippa | 2x2-rutnät | vippa
            HStack(spacing: 10) {
                TRRocker(title: "Kanal", upLabel: "Nästa kanal", downLabel: "Föregående kanal",
                         height: m.rocker,
                         up: { connection.press(.channelUp) }, down: { connection.press(.channelDown) })
                    .disabled(!connection.ready)
                VStack(spacing: m.keyGap) {
                    HStack(spacing: 10) {
                        smallKey("list.bullet.rectangle", "Öppna menyn", width: smallKeyWidth, height: m.smallKey) { connection.press(.guide) }
                            .disabled(!connection.ready)
                        smallKey("speaker.slash", "Stäng av ljudet", width: smallKeyWidth, height: m.smallKey) { connection.press(.mute) }
                            .disabled(!connection.ready)
                    }
                    HStack(spacing: 10) {
                        smallKey("gearshape", "TV:ns inställningar", width: smallKeyWidth, height: m.smallKey) { connection.press(.settings) }
                            .disabled(!connection.ready)
                        // Tangentbordet öppnar en panel i appen och behöver ingen TV.
                        smallKey("keyboard", "Öppna tangentbord", width: smallKeyWidth, height: m.smallKey) { openPanel(.keyboard) }
                    }
                }
                .frame(width: middle)
                TRRocker(title: "Volym", upLabel: "Höj volymen", downLabel: "Sänk volymen",
                         height: m.rocker,
                         up: { connection.press(.volumeUp) }, down: { connection.press(.volumeDown) })
                    .disabled(!connection.ready)
            }

            // D-pad: 3 x 82 kolumner, 3 x 72 rader, gap 10.
            VStack(spacing: TR.Size.dpadGap * (m.dpadRow / TR.Size.dpadRow)) {
                dpadRow(height: m.dpadRow) {
                    TRGhostButton(width: TR.Size.dpadColumn, height: m.dpadRow) {
                        openPanel(.numbers)
                    } label: {
                        Text("123").font(TR.Font.number)
                    }
                    // Sifferpanelen öppnas i appen och behöver ingen TV.
                    .accessibilityLabel("Sifferknappar")

                    dpadKey("chevron.up", "Upp", height: m.dpadRow) { connection.press(.up) }
                        .disabled(!connection.ready)

                    TRGhostButton(width: TR.Size.dpadColumn, height: m.dpadRow) {
                        Task { await connection.toggleVoice() }
                    } label: {
                        Image(systemName: connection.recording ? "stop.fill" : "mic")
                            .font(.system(size: 24))
                            .foregroundStyle(connection.recording ? TR.Colors.of(scheme).power : TR.Colors.of(scheme).text)
                    }
                    .accessibilityLabel(connection.recording ? "Stoppa röststyrning" : "Röststyrning")
                    .disabled(!connection.ready)
                }
                dpadRow(height: m.dpadRow) {
                    dpadKey("chevron.left", "Vänster", height: m.dpadRow) { connection.press(.left) }
                        .disabled(!connection.ready)
                    TROkKey(height: m.okKey) { connection.press(.ok) }
                        .frame(width: TR.Size.dpadColumn, height: m.dpadRow)
                        .disabled(!connection.ready)
                    dpadKey("chevron.right", "Höger", height: m.dpadRow) { connection.press(.right) }
                        .disabled(!connection.ready)
                }
                dpadRow(height: m.dpadRow) {
                    TRGhostButton(width: TR.Size.dpadColumn, height: m.dpadRow) {
                        connection.press(.back)
                    } label: {
                        Image(systemName: "arrow.left").font(.system(size: 24))
                    }
                    .accessibilityLabel("Gå tillbaka")
                    .disabled(!connection.ready)

                    dpadKey("chevron.down", "Ned", height: m.dpadRow) { connection.press(.down) }
                        .disabled(!connection.ready)

                    TRGhostButton(width: TR.Size.dpadColumn, height: m.dpadRow) {
                        connection.press(.home)
                    } label: {
                        Image(systemName: "house").font(.system(size: 24))
                    }
                    .accessibilityLabel("Till startsidan")
                    .disabled(!connection.ready)
                }
            }

            // Mediarad: fyra lika breda tangenter, höjd 44, gap 8.
            HStack(spacing: 8) {
                mediaKey("backward", "Spola bakåt", width: mediaWidth, height: m.media) { connection.press(.rewind) }
                mediaKey("play", "Spela", width: mediaWidth, height: m.media) { connection.press(.play) }
                mediaKey("pause", "Paus", width: mediaWidth, height: m.media) { connection.press(.pause) }
                mediaKey("forward", "Spola framåt", width: mediaWidth, height: m.media) { connection.press(.fastForward) }
            }
            .disabled(!connection.ready)
        }
        .padding(TR.Size.panelPadding)
        .frame(width: m.width, height: m.height)
        .background(
            RoundedRectangle(cornerRadius: TR.Radius.panel, style: .continuous).fill(colors.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TR.Radius.panel, style: .continuous).stroke(colors.line, lineWidth: 1)
        )
    }

    private func dpadRow<Content: View>(height: CGFloat,
                                        @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .frame(height: height)
    }

    private func dpadKey(_ icon: String, _ label: String, height: CGFloat,
                         action: @escaping () -> Void) -> some View {
        TRKey(width: TR.Size.dpadKeyWidth, height: max(height - 2, TR.Size.hitTargetMin),
              radius: TR.Radius.dpadKey, action: action) {
            Image(systemName: icon).font(.system(size: 22))
        }
        .frame(width: TR.Size.dpadColumn, height: height)
        .accessibilityLabel(label)
    }

    private func smallKey(_ icon: String, _ label: String, width: CGFloat, height: CGFloat,
                          action: @escaping () -> Void) -> some View {
        TRKey(width: width, height: height, radius: TR.Radius.smallKey, action: action) {
            Image(systemName: icon).font(.system(size: 20))
        }
        .accessibilityLabel(label)
    }

    private func mediaKey(_ icon: String, _ label: String, width: CGFloat, height: CGFloat,
                          action: @escaping () -> Void) -> some View {
        TRKey(width: width, height: height, radius: TR.Radius.mediaKey, action: action) {
            Image(systemName: icon).font(.system(size: 18))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Tema

    /// Temaknappen visar det valda läget. Bara vid Automatiskt beror den på
    /// omgivningen, som annars kan släpa efter en skrivning.
    private var themeScheme: ColorScheme {
        switch AppearanceMode(rawValue: appearanceRaw) ?? .system {
        case .light: return .light
        case .dark: return .dark
        case .system: return scheme
        }
    }

    private func toggleTheme() {
        appearanceRaw = (themeScheme == .dark ? AppearanceMode.light : AppearanceMode.dark).rawValue
    }

    private func useSystemTheme() {
        appearanceRaw = AppearanceMode.system.rawValue
        withAnimation(.easeOut(duration: 0.2)) { toast = "Utseende: Automatiskt" }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeOut(duration: 0.2)) { toast = nil }
        }
    }


}

enum RemoteState {
    case connected, connecting, disconnected, failed

    var text: String {
        switch self {
        case .connected: return "Ansluten"
        case .connecting: return "Ansluter…"
        case .disconnected: return "Inte ansluten"
        case .failed: return "Kunde inte ansluta"
        }
    }
    var pill: String {
        switch self {
        case .connected: return "Koppla från"
        case .connecting: return "Avbryt"
        case .disconnected: return "Anslut"
        case .failed: return "Försök igen"
        }
    }
    func textColor(_ colors: TR.Colors) -> Color {
        switch self {
        case .connected: return colors.greenText
        case .failed: return colors.power
        default: return colors.muted
        }
    }
    func dotColor(_ colors: TR.Colors) -> Color {
        switch self {
        case .connected: return colors.green
        case .connecting: return colors.green
        case .failed: return colors.power
        case .disconnected: return colors.muted
        }
    }
}

// Punkt 9 med glöd. Pulserar under anslutning.
struct StatusDot: View {
    var state: RemoteState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        let colors = TR.Colors.of(scheme)
        Circle()
            .fill(state.dotColor(colors))
            .frame(width: 9, height: 9)
            .shadow(color: state.dotColor(colors).opacity(0.7), radius: 5)
            .opacity(state == .connecting && dim && !reduceMotion ? 0.4 : 1)
            .animation(
                state == .connecting && !reduceMotion
                    ? .easeInOut(duration: 1).repeatForever(autoreverses: true)
                    : .default,
                value: dim
            )
            .onAppear { dim = true }
            .accessibilityHidden(true)
    }
}
