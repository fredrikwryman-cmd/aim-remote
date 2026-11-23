import SwiftUI
import AiMCore

// Fjärr, ritad efter facit sid 1 (ljust) och sid 2 (mörkt).
// Måtten är uppmätta i sid 1, referens 390 x 844.
@MainActor
struct RemoteScreen: View {
    @ObservedObject var connection: TVConnection
    var openPanel: (Panel) -> Void

    @Environment(\.colorScheme) private var scheme

    /// Panelen behåller facit-proportionerna och skalas bara i höjd, så att
    /// den fyller ytan ned till flikraden oavsett säker yta.
    private struct Metrics {
        var width: CGFloat
        var inner: CGFloat
        var scale: CGFloat
        var rocker: CGFloat
        var smallKey: CGFloat
        var smallKeyGap: CGFloat
        var dpadKey: CGFloat
        var dpadRowGap: CGFloat
        var media: CGFloat
        var gap: CGFloat
        var padTop: CGFloat
        var padBottom: CGFloat
        var height: CGFloat
        /// Bredder inom panelen
        var columnGap: CGFloat
        var keyWidth: CGFloat
        var dpadColumn: CGFloat
        var mediaWidth: CGFloat
    }

    private func metrics(width: CGFloat, height: CGFloat) -> Metrics {
        let inner = width - TR.Size.panelPaddingH * 2
        let columnGap = TR.Size.columnGap
        let keyWidth = max((inner - TR.Size.rockerWidth * 2 - columnGap * 3) / 2, TR.Size.hitTargetMin)
        let dpadColumn = max((inner - TR.Size.dpadColumnGap * 2) / 3, TR.Size.hitTargetMin)
        let mediaWidth = max((inner - columnGap * 3) / 4, TR.Size.hitTargetMin)

        let s = min(1.18, max(0.80, height / TR.Size.panelHeight))
        let dpadKey = min(dpadColumn, TR.Size.dpadKey * s)
        let rocker = TR.Size.rockerHeight * s
        let media = max(TR.Size.mediaKey * s, TR.Size.hitTargetMin)
        let gap = TR.Size.panelGap * s
        let padTop = TR.Size.panelPaddingTop * s
        let padBottom = TR.Size.panelPaddingBottom * s
        let dpadRowGap = TR.Size.dpadRowGap * s

        return Metrics(
            width: width,
            inner: inner,
            scale: s,
            rocker: rocker,
            smallKey: max(TR.Size.smallKey * s, TR.Size.hitTargetMin),
            smallKeyGap: TR.Size.smallKeyGap * s,
            dpadKey: dpadKey,
            dpadRowGap: dpadRowGap,
            media: media,
            gap: gap,
            padTop: padTop,
            padBottom: padBottom,
            height: padTop + rocker + gap + dpadKey * 3 + dpadRowGap * 2
                + gap + media + padBottom,
            columnGap: columnGap,
            keyWidth: keyWidth,
            dpadColumn: dpadColumn,
            mediaWidth: mediaWidth
        )
    }

    var body: some View {
        GeometryReader { geometry in
            // Flikraden är redan avdragen av RemoteRoot.
            let above = TR.Size.headerCard + 7 + TR.Size.statusRow + 13
            let m = metrics(width: geometry.size.width - TR.Size.sidePadding * 2,
                            height: max(geometry.size.height - above - 10, 1))
            VStack(alignment: .leading, spacing: 0) {
                header
                statusRow.padding(.top, 7)
                panel(m).padding(.top, 13)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, TR.Size.sidePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Toppkort

    private var header: some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.headerCard, style: .continuous)
        return HStack(spacing: 0) {
            PowerButton { connection.press(.power) }

            VStack(alignment: .leading, spacing: 0) {
                Text(connection.tvName)
                    .font(TR.Font.deviceTitle)
                    .trLabelScaling()
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                Text("Tech Rabbit Remote")
                    .font(TR.Font.caption)
                    .trLabelScaling()
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.leading, 19)

            Spacer(minLength: 8)

            TRIconButton(icon: "tv", variant: .ghost, iconSize: 24, label: "Välj TV") {
                openPanel(.chooseTV)
            }
        }
        .padding(.horizontal, TR.Size.headerPadding)
        .frame(height: TR.Size.headerCard)
        .background {
            // Facit ritar kortets yta i ljust läge; i mörkt ligger huvudet
            // direkt på bakgrunden (sid 1 mot sid 2).
            if scheme == .light {
                shape.fill(colors.surface)
                    .overlay(shape.stroke(colors.line, lineWidth: 1))
            }
        }
    }

    // MARK: - Statusrad

    private var statusRow: some View {
        let colors = TR.Colors.of(scheme)
        return HStack(spacing: 10) {
            StatusDot(state: state)
            Text(state.text)
                .font(TR.Font.body)
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
        .padding(.horizontal, TR.Size.statusInset)
        .frame(height: TR.Size.statusRow)
    }

    private var state: RemoteState {
        if connection.notice != nil && !connection.ready { return .failed }
        if connection.busy { return .connecting }
        return connection.ready ? .connected : .disconnected
    }

    // MARK: - Tangentpanelen

    private func panel(_ m: Metrics) -> some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: TR.Radius.panel, style: .continuous)

        return VStack(spacing: 0) {
            // Rad 1: Kanal-vippa, 2x2-rutnät, Volym-vippa.
            HStack(spacing: m.columnGap) {
                TRRocker(title: "Kanal", upLabel: "Nästa kanal", downLabel: "Föregående kanal",
                         height: m.rocker, keyHeight: m.rocker * 0.378,
                         up: { connection.press(.channelUp) },
                         down: { connection.press(.channelDown) })
                    .disabled(!connection.ready)

                VStack(spacing: m.smallKeyGap) {
                    HStack(spacing: m.columnGap) {
                        smallKey("list.bullet.rectangle", "Öppna menyn", m) { connection.press(.guide) }
                            .disabled(!connection.ready)
                        smallKey("speaker.slash", "Stäng av ljudet", m) { connection.press(.mute) }
                            .disabled(!connection.ready)
                    }
                    HStack(spacing: m.columnGap) {
                        smallKey("gearshape", "TV:ns inställningar", m) { connection.press(.settings) }
                            .disabled(!connection.ready)
                        // Tangentbordet öppnar en panel i appen och behöver ingen TV.
                        smallKey("keyboard", "Öppna tangentbord", m) { openPanel(.keyboard) }
                    }
                }
                .frame(height: m.rocker)

                TRRocker(title: "Volym", upLabel: "Höj volymen", downLabel: "Sänk volymen",
                         height: m.rocker, keyHeight: m.rocker * 0.378,
                         up: { connection.press(.volumeUp) },
                         down: { connection.press(.volumeDown) })
                    .disabled(!connection.ready)
            }
            .frame(height: m.rocker)

            Spacer(minLength: 0).frame(height: m.gap)

            // Rad 2: 3 x 3 med 123, pilar, OK, mikrofon, tillbaka och hem.
            VStack(spacing: m.dpadRowGap) {
                HStack(spacing: m.columnGap) {
                    ghost(m, "Sifferknappar") { openPanel(.numbers) } label: {
                        Text("123").font(TR.Font.numeric)
                    }
                    dpadKey("chevron.up", "Upp", m) { connection.press(.up) }
                        .disabled(!connection.ready)
                    ghost(m, connection.recording ? "Stoppa röststyrning" : "Röststyrning") {
                        Task { await connection.toggleVoice() }
                    } label: {
                        Image(systemName: connection.recording ? "stop.fill" : "mic")
                            .font(.system(size: 26))
                            .foregroundStyle(connection.recording
                                             ? TR.Colors.of(scheme).danger
                                             : TR.Colors.of(scheme).textPrimary)
                    }
                    .disabled(!connection.ready)
                }
                HStack(spacing: m.columnGap) {
                    dpadKey("chevron.left", "Vänster", m) { connection.press(.left) }
                        .disabled(!connection.ready)
                    TRKey(width: m.dpadKey, height: m.dpadKey, radius: TR.Radius.dpadKey) {
                        TRHaptics.ok()
                        connection.press(.ok)
                    } label: {
                        Text("OK").font(.system(size: 21, weight: .bold))
                    }
                    .frame(width: m.dpadColumn, height: m.dpadKey)
                    .accessibilityLabel("Bekräfta")
                    .disabled(!connection.ready)
                    dpadKey("chevron.right", "Höger", m) { connection.press(.right) }
                        .disabled(!connection.ready)
                }
                HStack(spacing: m.columnGap) {
                    ghost(m, "Gå tillbaka") { connection.press(.back) } label: {
                        Image(systemName: "arrow.left").font(.system(size: 26))
                    }
                    .disabled(!connection.ready)
                    dpadKey("chevron.down", "Ned", m) { connection.press(.down) }
                        .disabled(!connection.ready)
                    ghost(m, "Till startsidan") { connection.press(.home) } label: {
                        Image(systemName: "house").font(.system(size: 26))
                    }
                    .disabled(!connection.ready)
                }
            }

            Spacer(minLength: 0).frame(height: m.gap)

            // Rad 3: mediatangenter.
            HStack(spacing: m.columnGap) {
                mediaKey("backward", "Spola bakåt", m) { connection.press(.rewind) }
                mediaKey("play", "Spela", m) { connection.press(.play) }
                mediaKey("pause", "Paus", m) { connection.press(.pause) }
                mediaKey("forward", "Spola framåt", m) { connection.press(.fastForward) }
            }
            .disabled(!connection.ready)
        }
        .padding(.horizontal, TR.Size.panelPaddingH)
        .padding(.top, m.padTop)
        .padding(.bottom, m.padBottom)
        .frame(width: m.width, height: m.height)
        .background(shape.fill(colors.panel))
        .overlay(shape.stroke(colors.line, lineWidth: 1))
    }

    private func smallKey(_ icon: String, _ label: String, _ m: Metrics,
                          action: @escaping () -> Void) -> some View {
        TRKey(width: m.keyWidth, height: m.smallKey,
              radius: min(TR.Radius.smallKey, m.smallKey / 2), action: action) {
            Image(systemName: icon).font(.system(size: 22))
        }
        .accessibilityLabel(label)
    }

    private func dpadKey(_ icon: String, _ label: String, _ m: Metrics,
                         action: @escaping () -> Void) -> some View {
        TRKey(width: m.dpadKey, height: m.dpadKey, radius: TR.Radius.dpadKey,
              repeats: true, action: action) {
            Image(systemName: icon).font(.system(size: 24, weight: .medium))
        }
        .frame(width: m.dpadColumn, height: m.dpadKey)
        .accessibilityLabel(label)
    }

    private func ghost<L: View>(_ m: Metrics, _ label: String,
                                action: @escaping () -> Void,
                                @ViewBuilder label content: () -> L) -> some View {
        TRGhostButton(width: m.dpadColumn, height: m.dpadKey, action: action, label: content)
            .accessibilityLabel(label)
    }

    private func mediaKey(_ icon: String, _ label: String, _ m: Metrics,
                          action: @escaping () -> Void) -> some View {
        TRKey(width: m.mediaWidth, height: m.media,
              radius: min(TR.Radius.mediaKey, m.media / 2), action: action) {
            Image(systemName: icon).font(.system(size: 20))
        }
        .accessibilityLabel(label)
    }
}

// Av- och påknappen: röd symbol i en rund yta, med rött sken i ljust läge.
private struct PowerButton: View {
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        Button {
            TRHaptics.power()
            action()
        } label: {
            Image(systemName: "power")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(colors.danger)
                .frame(width: TR.Size.powerButton, height: TR.Size.powerButton)
                .background {
                    Circle()
                        .fill(colors.surfaceElevated)
                        .shadow(color: colors.danger.opacity(scheme == .dark ? 0 : 0.22),
                                radius: 10)
                }
                .contentShape(Circle())
        }
        .buttonStyle(TRPressStyle())
        .accessibilityLabel("Slå på eller av TV:n")
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
        case .connected: return colors.accentText
        case .failed: return colors.danger
        default: return colors.textPrimary
        }
    }
    func dotColor(_ colors: TR.Colors) -> Color {
        switch self {
        case .connected, .connecting: return colors.accent
        case .failed: return colors.danger
        case .disconnected: return colors.textSecondary
        }
    }
}

// Punkten i statusraden. Pulserar under anslutning.
struct StatusDot: View {
    var state: RemoteState
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        let colors = TR.Colors.of(scheme)
        Circle()
            .fill(state.dotColor(colors))
            .frame(width: TR.Size.statusDot, height: TR.Size.statusDot)
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
