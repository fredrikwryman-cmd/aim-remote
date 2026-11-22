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

    // Panelens höjd med fasta mått: padding + vippa + gap + 3 d-pad-rader + gap + mediarad + padding.
    private var panelHeight: CGFloat {
        TR.Size.panelPadding * 2 + TR.Size.rockerHeight + TR.Size.panelGap
            + TR.Size.dpadRow * 3 + TR.Size.panelGap + TR.Size.mediaKey
    }

    var body: some View {
        GeometryReader { geometry in
            let needed = TR.Size.headerRow + 14 + TR.Size.pillHeight + 16 + panelHeight
            let available = geometry.size.height - TR.Size.tabBar - TR.Size.tabBarBottom - 8
            let scale = max(0.86, min(1, available / max(needed, 1)))
            VStack(alignment: .leading, spacing: 0) {
                header
                statusRow.padding(.top, 14)
                panel
                    .padding(.top, 16)
                    .scaleEffect(scale, anchor: .top)
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
                icon: scheme == .dark ? "sun.max" : "moon",
                variant: .flat,
                label: scheme == .dark ? "Byt till ljust utseende" : "Byt till mörkt utseende",
                action: toggleTheme,
                longPress: useSystemTheme
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

    private var panel: some View {
        let colors = TR.Colors.of(scheme)
        let inner = 390 - TR.Size.sidePadding * 2 - TR.Size.panelPadding * 2   // 330
        let middle = inner - TR.Size.rockerWidth * 2 - 20                       // 170
        let smallKeyWidth = (middle - 10) / 2                                   // 80
        let mediaWidth = (inner - 24) / 4

        return VStack(spacing: TR.Size.panelGap) {
            // Övre rad: vippa | 2x2-rutnät | vippa
            HStack(spacing: 10) {
                TRRocker(title: "Kanal", upLabel: "Nästa kanal", downLabel: "Föregående kanal",
                         up: { connection.press(.channelUp) }, down: { connection.press(.channelDown) })
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        smallKey("list.bullet.rectangle", "Öppna menyn", width: smallKeyWidth) { connection.press(.guide) }
                        smallKey("speaker.slash", "Stäng av ljudet", width: smallKeyWidth) { connection.press(.mute) }
                    }
                    HStack(spacing: 10) {
                        smallKey("gearshape", "TV:ns inställningar", width: smallKeyWidth) { connection.press(.settings) }
                        smallKey("keyboard", "Öppna tangentbord", width: smallKeyWidth) { openPanel(.keyboard) }
                    }
                }
                .frame(width: middle)
                TRRocker(title: "Volym", upLabel: "Höj volymen", downLabel: "Sänk volymen",
                         up: { connection.press(.volumeUp) }, down: { connection.press(.volumeDown) })
            }
            .disabled(!connection.ready)

            // D-pad: 3 x 82 kolumner, 3 x 72 rader, gap 10.
            VStack(spacing: 0) {
                dpadRow {
                    TRGhostButton(width: TR.Size.dpadColumn, height: TR.Size.dpadRow) {
                        openPanel(.numbers)
                    } label: {
                        Text("123").font(TR.Font.number)
                    }
                    .accessibilityLabel("Sifferknappar")

                    dpadKey("chevron.up", "Upp") { connection.press(.up) }

                    TRGhostButton(width: TR.Size.dpadColumn, height: TR.Size.dpadRow) {
                        Task { await connection.toggleVoice() }
                    } label: {
                        Image(systemName: connection.recording ? "stop.fill" : "mic")
                            .font(.system(size: 24))
                            .foregroundStyle(connection.recording ? TR.Colors.of(scheme).power : TR.Colors.of(scheme).text)
                    }
                    .accessibilityLabel(connection.recording ? "Stoppa röststyrning" : "Röststyrning")
                }
                dpadRow {
                    dpadKey("chevron.left", "Vänster") { connection.press(.left) }
                    TROkKey { connection.press(.ok) }
                        .frame(width: TR.Size.dpadColumn, height: TR.Size.dpadRow)
                    dpadKey("chevron.right", "Höger") { connection.press(.right) }
                }
                dpadRow {
                    TRGhostButton(width: TR.Size.dpadColumn, height: TR.Size.dpadRow) {
                        connection.press(.back)
                    } label: {
                        Image(systemName: "arrow.left").font(.system(size: 24))
                    }
                    .accessibilityLabel("Gå tillbaka")

                    dpadKey("chevron.down", "Ned") { connection.press(.down) }

                    TRGhostButton(width: TR.Size.dpadColumn, height: TR.Size.dpadRow) {
                        connection.press(.home)
                    } label: {
                        Image(systemName: "house").font(.system(size: 24))
                    }
                    .accessibilityLabel("Till startsidan")
                }
            }
            .disabled(!connection.ready)

            // Mediarad: fyra lika breda tangenter, höjd 44, gap 8.
            HStack(spacing: 8) {
                mediaKey("backward", "Spola bakåt", width: mediaWidth) { connection.press(.rewind) }
                mediaKey("play", "Spela", width: mediaWidth) { connection.press(.play) }
                mediaKey("pause", "Paus", width: mediaWidth) { connection.press(.pause) }
                mediaKey("forward", "Spola framåt", width: mediaWidth) { connection.press(.fastForward) }
            }
            .disabled(!connection.ready)
        }
        .padding(TR.Size.panelPadding)
        .frame(width: 390 - TR.Size.sidePadding * 2, height: panelHeight)
        .background(
            RoundedRectangle(cornerRadius: TR.Radius.panel, style: .continuous).fill(colors.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TR.Radius.panel, style: .continuous).stroke(colors.line, lineWidth: 1)
        )
    }

    private func dpadRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .frame(height: TR.Size.dpadRow)
    }

    private func dpadKey(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        TRKey(width: TR.Size.dpadKeyWidth, height: TR.Size.dpadKeyHeight,
              radius: TR.Radius.dpadKey, action: action) {
            Image(systemName: icon).font(.system(size: 22))
        }
        .frame(width: TR.Size.dpadColumn, height: TR.Size.dpadRow)
        .accessibilityLabel(label)
    }

    private func smallKey(_ icon: String, _ label: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        TRKey(width: width, height: TR.Size.smallKey, radius: TR.Radius.smallKey, action: action) {
            Image(systemName: icon).font(.system(size: 20))
        }
        .accessibilityLabel(label)
    }

    private func mediaKey(_ icon: String, _ label: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        TRKey(width: width, height: TR.Size.mediaKey, radius: TR.Radius.mediaKey, action: action) {
            Image(systemName: icon).font(.system(size: 18))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Tema

    private func toggleTheme() {
        appearanceRaw = (scheme == .dark ? AppearanceMode.light : AppearanceMode.dark).rawValue
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
