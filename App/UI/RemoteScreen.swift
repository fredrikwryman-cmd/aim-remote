import SwiftUI
import AiMCore

// Fjärr. Ljust läge ritas efter facit sid 1, mörkt efter sid 2. Måtten
// ligger i TR.Layout och är uppmätta i respektive sida (390 x 844).
@MainActor
struct RemoteScreen: View {
    @ObservedObject var connection: TVConnection
    var openPanel: (Panel) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Panelen behåller facit-proportionerna. Bredderna skalas mot facit-
    /// sidans innerbredd, höjden mot ytan som finns kvar ned till flikraden.
    private struct Metrics {
        var l: TR.Layout
        var width: CGFloat
        var inner: CGFloat
        var h: CGFloat          // bredd-skala
        var v: CGFloat          // höjd-skala
        var rocker: CGFloat
        var rockerHeight: CGFloat
        var keyWidth: CGFloat
        var smallKey: CGFloat
        var smallKeyGap: CGFloat
        var columnGap: CGFloat
        var dpadKey: CGFloat
        var dpadColumnGap: CGFloat
        var dpadRow: CGFloat
        var dpadRowGap: CGFloat
        var mediaWidth: CGFloat
        var mediaHeight: CGFloat
        var mediaGap: CGFloat
        var gapRockerDpad: CGFloat
        var gapDpadMedia: CGFloat
        var padTop: CGFloat
        var padBottom: CGFloat
        var height: CGFloat
    }

    private func metrics(width: CGFloat, height: CGFloat) -> Metrics {
        let l = TR.Layout.of(scheme)
        let inner = width - l.panelPaddingH * 2
        let h = inner / l.referenceInner
        let v = min(1.18, max(0.80, height / l.panelHeight))

        let rocker = l.rockerWidth * h
        let columnGap = l.columnGap * h
        let keyWidth = max((inner - rocker * 2 - columnGap * 3) / 2, TR.Size.hitTargetMin)
        let dpadKey = l.dpadKey * h
        let mediaWidth = max(l.mediaWidth * h, TR.Size.hitTargetMin)

        let rockerHeight = l.rockerHeight * v
        let dpadRow = min(dpadKey, l.dpadRow * v)
        let mediaHeight = max(l.mediaHeight * v, TR.Size.hitTargetMin)
        let gapRockerDpad = l.gapRockerDpad * v
        let gapDpadMedia = l.gapDpadMedia * v
        let dpadRowGap = l.dpadRowGap * v
        let padTop = l.panelPaddingTop * v
        let padBottom = l.panelPaddingBottom * v

        return Metrics(
            l: l,
            width: width,
            inner: inner,
            h: h,
            v: v,
            rocker: rocker,
            rockerHeight: rockerHeight,
            keyWidth: keyWidth,
            smallKey: max(l.smallKey * v, TR.Size.hitTargetMin),
            smallKeyGap: l.smallKeyGap * v,
            columnGap: columnGap,
            dpadKey: dpadKey,
            dpadColumnGap: l.dpadColumnGap * h,
            dpadRow: dpadRow,
            dpadRowGap: dpadRowGap,
            mediaWidth: mediaWidth,
            mediaHeight: mediaHeight,
            mediaGap: l.mediaGap * h,
            gapRockerDpad: gapRockerDpad,
            gapDpadMedia: gapDpadMedia,
            padTop: padTop,
            padBottom: padBottom,
            height: padTop + rockerHeight + gapRockerDpad + dpadRow * 3
                + dpadRowGap * 2 + gapDpadMedia + mediaHeight + padBottom
        )
    }

    var body: some View {
        let l = TR.Layout.of(scheme)
        return GeometryReader { geometry in
            // Flikraden är redan avdragen av RemoteRoot.
            let above = l.topPadding + l.headerHeight + l.gapHeaderStatus
                + l.statusRow + l.gapStatusPanel
            let m = metrics(width: geometry.size.width - l.sidePadding * 2,
                            height: max(geometry.size.height - above - 10, 1))
            VStack(alignment: .leading, spacing: 0) {
                header(l)
                statusRow(l).padding(.top, l.gapHeaderStatus)
                panel(m).padding(.top, l.gapStatusPanel)
                Spacer(minLength: 0)
            }
            .padding(.top, l.topPadding)
            .padding(.horizontal, l.sidePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Toppkort

    private func header(_ l: TR.Layout) -> some View {
        let colors = TR.Colors.of(scheme)
        let shape = RoundedRectangle(cornerRadius: l.headerHeight / 2, style: .continuous)
        return HStack(spacing: 0) {
            PowerButton(size: l.powerButton, icon: l.powerIcon) { connection.press(.power) }

            VStack(alignment: .leading, spacing: 0) {
                Text(connection.tvName)
                    .font(TR.Font.deviceTitle)
                    .trLabelScaling()
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Tech Rabbit Remote")
                    .font(TR.Font.caption)
                    .trLabelScaling()
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, l.headerTextGap)

            Spacer(minLength: 8)

            Button {
                openPanel(.chooseTV)
            } label: {
                TRDisplayIcon(width: l.displayIcon, color: colors.textPrimary)
                    .frame(width: TR.Size.hitTargetMin, height: TR.Size.hitTargetMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TRPressStyle())
            .accessibilityLabel("Välj TV")
            .panelSource(.chooseTV)
        }
        .padding(.horizontal, l.headerPadding)
        .frame(height: l.headerHeight)
        .background {
            // Facit sid 1 ritar kortets yta; sid 2 lägger huvudet direkt på
            // bakgrunden.
            if l.headerFilled {
                shape.fill(colors.surface)
                    .overlay(shape.stroke(colors.line, lineWidth: 1))
            }
        }
    }

    // MARK: - Statusrad

    private func statusRow(_ l: TR.Layout) -> some View {
        let colors = TR.Colors.of(scheme)
        return HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                HStack(spacing: 10) {
                    StatusDot(state: state)
                    Text(state.text)
                        .font(TR.Font.body)
                        .trLabelScaling()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(state.textColor(colors))
                }
                .id(state)
                .transition(.opacity)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenStatus)

            Spacer(minLength: 8)

            // Ansluten: pillret behovs inte langre och doljs.
            if state != .connected {
                TRStatusPill(title: state.pill, height: l.statusRow) {
                    openPanel(.chooseTV)
                }
                .disabled(state == .connecting)
                .accessibilityLabel(state.pill)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, l.statusInset)
        .frame(height: l.statusRow)
        .animation(.easeInOut(duration: TRMotion.swap), value: state)
    }

    /// Punkt 19: VoiceOver laser hela statusen, inte bara ordet.
    private var spokenStatus: String {
        switch state {
        case .connected: return "Ansluten till \(connection.tvName)"
        case .connecting: return "Ansluter till \(connection.tvName)"
        case .disconnected: return "Inte ansluten till \(connection.tvName)"
        case .failed: return "Kunde inte ansluta till \(connection.tvName)"
        }
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
                rocker("Kanal", "Nästa kanal", "Föregående kanal", m,
                       up: { connection.press(.channelUp) },
                       down: { connection.press(.channelDown) })

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
                            .panelSource(.keyboard)
                    }
                }
                .frame(height: m.rockerHeight)

                rocker("Volym", "Höj volymen", "Sänk volymen", m,
                       up: { connection.press(.volumeUp) },
                       down: { connection.press(.volumeDown) })
            }
            .frame(height: m.rockerHeight)

            Spacer(minLength: 0).frame(height: m.gapRockerDpad)

            // Rad 2: 3 x 3 med 123, pilar, OK, mikrofon, tillbaka och hem.
            VStack(spacing: m.dpadRowGap) {
                HStack(spacing: m.dpadColumnGap) {
                    ghost(m, "Sifferknappar") { openPanel(.numbers) } label: {
                        Text("123").font(TR.Font.numeric)
                    }
                    .panelSource(.numbers)
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
                HStack(spacing: m.dpadColumnGap) {
                    dpadKey("chevron.left", "Vänster", m) { connection.press(.left) }
                        .disabled(!connection.ready)
                    TRKey(width: m.dpadKey, height: m.dpadRow, radius: TR.Radius.dpadKey,
                          dims: false) {
                        TRHaptics.key()
                        connection.press(.ok)
                    } label: {
                        Text("OK").font(.system(size: 21, weight: .bold))
                    }
                    .accessibilityLabel("Bekräfta")
                    .disabled(!connection.ready)
                    dpadKey("chevron.right", "Höger", m) { connection.press(.right) }
                        .disabled(!connection.ready)
                }
                HStack(spacing: m.dpadColumnGap) {
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

            Spacer(minLength: 0).frame(height: m.gapDpadMedia)

            // Rad 3: mediatangenter.
            HStack(spacing: m.mediaGap) {
                mediaKey("backward", "Spola bakåt", m) { connection.press(.rewind) }
                mediaKey("play", "Spela", m) { connection.press(.play) }
                mediaKey("pause", "Paus", m) { connection.press(.pause) }
                mediaKey("forward", "Spola framåt", m) { connection.press(.fastForward) }
            }
            .disabled(!connection.ready)
        }
        .padding(.horizontal, m.l.panelPaddingH)
        .padding(.top, m.padTop)
        .padding(.bottom, m.padBottom)
        .frame(width: m.width, height: m.height)
        .background(shape.fill(colors.panel))
        .overlay(shape.stroke(colors.line, lineWidth: 1))
    }

    private func rocker(_ title: String, _ upLabel: String, _ downLabel: String, _ m: Metrics,
                        up: @escaping () -> Void, down: @escaping () -> Void) -> some View {
        TRRocker(title: title, upLabel: upLabel, downLabel: downLabel,
                 width: m.rocker, height: m.rockerHeight,
                 split: m.l.rockerSplit,
                 keyHeight: m.l.rockerKey * m.v,
                 inset: m.l.rockerInset,
                 up: up, down: down)
            .disabled(!connection.ready)
    }

    private func smallKey(_ icon: String, _ label: String, _ m: Metrics,
                          action: @escaping () -> Void) -> some View {
        TRKey(width: m.keyWidth, height: m.smallKey,
              radius: min(TR.Radius.smallKey, m.smallKey / 2),
              dims: false, action: action) {
            Image(systemName: icon).font(.system(size: 22))
        }
        .accessibilityLabel(label)
    }

    private func dpadKey(_ icon: String, _ label: String, _ m: Metrics,
                         action: @escaping () -> Void) -> some View {
        TRKey(width: m.dpadKey, height: m.dpadRow, radius: TR.Radius.dpadKey,
              repeats: true, dims: false, action: action) {
            Image(systemName: icon).font(.system(size: 24, weight: .medium))
        }
        .accessibilityLabel(label)
    }

    private func ghost<L: View>(_ m: Metrics, _ label: String,
                                action: @escaping () -> Void,
                                @ViewBuilder label content: () -> L) -> some View {
        TRGhostButton(width: m.dpadKey, height: m.dpadRow, dims: false,
                      action: action, label: content)
            .accessibilityLabel(label)
    }

    private func mediaKey(_ icon: String, _ label: String, _ m: Metrics,
                          action: @escaping () -> Void) -> some View {
        TRKey(width: m.mediaWidth, height: m.mediaHeight,
              radius: min(TR.Radius.mediaKey, m.mediaHeight / 2),
              dims: false, action: action) {
            Image(systemName: icon).font(.system(size: 20))
        }
        .accessibilityLabel(label)
    }
}

// Av- och påknappen: röd symbol i en rund yta, med rött sken i ljust läge.
private struct PowerButton: View {
    var size: CGFloat
    var icon: CGFloat
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let colors = TR.Colors.of(scheme)
        Button {
            TRHaptics.key()
            action()
        } label: {
            Image(systemName: "power")
                .font(.system(size: icon, weight: .medium))
                .foregroundStyle(colors.danger)
                .frame(width: size, height: size)
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
        case .connecting: return "Ansluter…"
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
    @State private var blinkScale: CGFloat = 1
    @State private var blinkOpacity: Double = 0

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
            .overlay {
                Circle()
                    .fill(colors.accent)
                    .frame(width: TR.Size.statusDot, height: TR.Size.statusDot)
                    .scaleEffect(blinkScale)
                    .opacity(blinkOpacity)
                    .allowsHitTesting(false)
            }
            .onAppear { start() }
            .accessibilityHidden(true)
    }

    /// Pricken fods i det nya laget: statusraden byter identitet vid
    /// lagesbyte. Ar laget Ansluten blinkar den en gang, annars bara pulsen.
    private func start() {
        dim = true
        guard state == .connected else { return }
        blinkOpacity = 1
        if reduceMotion {
            withAnimation(TRMotion.crossfade) { blinkOpacity = 0 }
        } else {
            withAnimation(.easeOut(duration: 0.45)) {
                blinkScale = 2.6
                blinkOpacity = 0
            }
        }
    }
}
