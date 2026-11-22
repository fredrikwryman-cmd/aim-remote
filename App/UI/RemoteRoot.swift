import SwiftUI
import AiMCore
import UIKit

enum Panel: String, Identifiable {
    case connection, numbers, keyboard, help
    var id: String { rawValue }
}

enum MainTab { case remote, settings }

@MainActor
struct RemoteRoot: View {
    @ObservedObject var connection: TVConnection
    @AppStorage("haptics") private var haptics = true
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var tab: MainTab = .remote
    @State private var panel: Panel?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = scheme.palette
        ZStack {
            PremiumBackground(screen: tab == .remote ? .remote : .settings)
            Group {
                if tab == .remote {
                    remoteScreen
                } else {
                    SettingsScreen(
                        connection: connection,
                        haptics: $haptics,
                        appearanceRaw: $appearanceRaw,
                        openPanel: { panel = $0 }
                    )
                }
            }
        }
        .tint(palette.accentText)
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .sheet(item: $panel) { selection in
            switch selection {
            case .connection: ConnectionView(connection: connection)
            case .numbers: NumberPadView(connection: connection, haptics: haptics, openPanel: { panel = $0 })
            case .keyboard: KeyboardView(connection: connection)
            case .help: HelpView()
            }
        }
        .alert(
            "Tech Rabbit Remote",
            isPresented: Binding(
                get: { connection.notice != nil && panel == nil },
                set: { if !$0 { connection.notice = nil } }
            )
        ) {
            Button("OK") { connection.notice = nil }
        } message: { Text(connection.notice ?? "") }
    }

    // MARK: - Fjärren

    private var remoteScreen: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, 430)
            let compact = geometry.size.height < 700
            VStack(spacing: 0) {
                header()
                statusRow()
                    .padding(.top, compact ? 8 : 12)
                remotePanel(width: width, compact: compact)
                    .padding(.top, compact ? 8 : 11)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, max(11, (geometry.size.width - width) / 2 + 11))
            .padding(.top, 2)
        }
    }

    private func header() -> some View {
        let palette = scheme.palette
        return HStack(spacing: 15) {
            Button { tap(.power) } label: {
                Image(systemName: "power")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.danger)
                    .frame(width: 52, height: 52)
                    .background(
                        RadialGradient(colors: palette.powerStops, center: .center, startRadius: 2, endRadius: 34),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(palette.surfaceBorder, lineWidth: 1))
                    .shadow(color: scheme == .dark ? .black.opacity(0.5) : palette.danger.opacity(0.16), radius: 9, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Slå på eller av TV:n")

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.tvName)
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text("Tech Rabbit Remote")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 4)

            Button(action: toggleAppearance) {
                Image(systemName: scheme == .dark ? "sun.max" : "moon")
                    .font(.system(size: 19))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(GlassButtonStyle(radius: 22))
            .accessibilityLabel(scheme == .dark ? "Byt till ljust utseende" : "Byt till mörkt utseende")

            Button { panel = .connection } label: {
                Image(systemName: "tv")
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(BareButtonStyle())
            .accessibilityLabel("TV och anslutning")
        }
        .frame(height: 52)
    }

    private func statusRow() -> some View {
        let palette = scheme.palette
        return HStack(spacing: 8) {
            if connection.busy {
                ProgressView().controlSize(.small)
            } else {
                Circle()
                    .fill(connection.ready ? palette.success : palette.textMuted)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            Text(connection.status)
                .font(.system(size: 13))
                .foregroundStyle(connection.ready ? palette.success : palette.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                if connection.ready { connection.disconnect() } else { panel = .connection }
            } label: {
                Text(connection.ready ? "Koppla från" : "Anslut")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.connectText)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(palette.accentSubtle, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(connection.ready ? "Koppla från TV:n" : "Anslut till TV")
        }
        .frame(height: 34)
        .padding(.horizontal, 4)
    }

    private func remotePanel(width: CGFloat, compact: Bool) -> some View {
        let inset: CGFloat = 16.5
        let content = width - inset * 2
        let small = (content - 36) / 4
        let dpadGap = content * 0.09
        let dpad = (content - dpadGap * 2) / 3
        let dpadHeight: CGFloat = compact ? 64 : 84
        let media = (content - 34) / 4
        let sectionGap: CGFloat = compact ? 12 : 21

        return VStack(spacing: sectionGap) {
            HStack(alignment: .center, spacing: 12) {
                rocker("Kanal", up: .channelUp, down: .channelDown,
                       width: small, height: compact ? 112 : 133,
                       upLabel: "Nästa kanal", downLabel: "Föregående kanal")
                VStack(spacing: compact ? 16 : 28) {
                    glassKey("list.bullet.rectangle", "Öppna menyn", width: small, height: compact ? 44 : 47) { tap(.guide) }
                    glassKey("gearshape", "TV:ns inställningar", width: small, height: compact ? 44 : 47) { tap(.settings) }
                }
                VStack(spacing: compact ? 16 : 28) {
                    glassKey("speaker.slash", "Stäng av ljudet", width: small, height: compact ? 44 : 47) { tap(.mute) }
                    glassKey("keyboard", "Öppna tangentbord", width: small, height: compact ? 44 : 47) { panel = .keyboard }
                }
                rocker("Volym", up: .volumeUp, down: .volumeDown,
                       width: small, height: compact ? 112 : 133,
                       upLabel: "Höj volymen", downLabel: "Sänk volymen")
            }

            VStack(spacing: 12) {
                HStack(spacing: dpadGap) {
                    Button { panel = .numbers } label: {
                        Text("123")
                            .font(.system(size: 26))
                            .frame(width: dpad, height: dpadHeight)
                    }
                    .buttonStyle(BareButtonStyle())
                    .accessibilityLabel("Sifferknappar")

                    glassKey("chevron.up", "Upp", width: dpad, height: dpadHeight, radius: 26) { tap(.up) }

                    Button { Task { await connection.toggleVoice() } } label: {
                        Image(systemName: connection.recording ? "stop.fill" : "mic")
                            .font(.system(size: 30))
                            .foregroundStyle(connection.recording ? scheme.palette.danger : scheme.palette.iconPrimary)
                            .frame(width: dpad, height: dpadHeight)
                    }
                    .buttonStyle(BareButtonStyle())
                    .accessibilityLabel(connection.recording ? "Stoppa röststyrning" : "Röststyrning")
                }
                HStack(spacing: dpadGap) {
                    glassKey("chevron.left", "Vänster", width: dpad, height: dpadHeight, radius: 26) { tap(.left) }
                    Button { tap(.ok) } label: {
                        Text("OK")
                            .font(.system(size: 21, weight: .semibold))
                            .frame(width: dpad, height: dpadHeight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(scheme.palette.accent, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(GlassButtonStyle(radius: 26))
                    .accessibilityLabel("Bekräfta")
                    glassKey("chevron.right", "Höger", width: dpad, height: dpadHeight, radius: 26) { tap(.right) }
                }
                HStack(spacing: dpadGap) {
                    Button { tap(.back) } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 30))
                            .frame(width: dpad, height: dpadHeight)
                    }
                    .buttonStyle(BareButtonStyle())
                    .accessibilityLabel("Gå tillbaka")

                    glassKey("chevron.down", "Ned", width: dpad, height: dpadHeight, radius: 26) { tap(.down) }

                    Button { tap(.home) } label: {
                        Image(systemName: "house")
                            .font(.system(size: 30))
                            .frame(width: dpad, height: dpadHeight)
                    }
                    .buttonStyle(BareButtonStyle())
                    .accessibilityLabel("Till startsidan")
                }
            }

            if connection.recording || connection.awaitingVoice {
                Text(connection.recording ? "Lyssnar… tryck på stopp när du är klar" : "Väntar på TV:ns mikrofon…")
                    .font(.system(size: 13))
                    .foregroundStyle(scheme.palette.accentText)
            }

            HStack(spacing: 11.4) {
                glassKey("backward", "Föregående", width: media, height: compact ? 44 : 47) { tap(.rewind) }
                glassKey("play", "Spela", width: media, height: compact ? 44 : 47) { tap(.play) }
                glassKey("pause", "Pausa", width: media, height: compact ? 44 : 47) { tap(.pause) }
                glassKey("forward", "Nästa", width: media, height: compact ? 44 : 47) { tap(.fastForward) }
            }
        }
        .padding(.horizontal, inset)
        .padding(.top, compact ? 14 : 21)
        .padding(.bottom, compact ? 20 : 35)
        .frame(width: width)
        .panelSurface(radius: 27)
    }

    // MARK: - Byggstenar

    private func glassKey(
        _ symbol: String, _ label: String,
        width: CGFloat, height: CGFloat, radius: CGFloat = 23.5,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: height > 60 ? 28 : 24))
                .frame(width: width, height: height)
        }
        .buttonStyle(GlassButtonStyle(radius: radius))
        .accessibilityLabel(label)
    }

    private func rocker(
        _ title: String, up: TVKey, down: TVKey,
        width: CGFloat, height: CGFloat,
        upLabel: String, downLabel: String
    ) -> some View {
        let palette = scheme.palette
        let shape = RoundedRectangle(cornerRadius: width * 0.5, style: .continuous)
        return VStack(spacing: 0) {
            Button { tap(up) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 22))
                    .frame(width: width, height: (height - 27) / 2)
            }
            .buttonStyle(BareButtonStyle())
            .accessibilityLabel(upLabel)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
                .frame(height: 27)
                .accessibilityHidden(true)

            Button { tap(down) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 22))
                    .frame(width: width, height: (height - 27) / 2)
            }
            .buttonStyle(BareButtonStyle())
            .accessibilityLabel(downLabel)
        }
        .frame(width: width, height: height)
        .background(angledGradient(palette.rockerStops, angle: palette.rockerAngle), in: shape)
        .overlay(shape.stroke(scheme == .dark ? .white.opacity(0.20) : palette.surfaceBorder, lineWidth: 1))
        .shadow(
            color: scheme == .dark ? .black.opacity(0.5) : Color(hex: 0x141E28, opacity: 0.06),
            radius: scheme == .dark ? 13 : 8,
            y: scheme == .dark ? 12 : 6
        )
    }

    private var tabBar: some View {
        let palette = scheme.palette
        return HStack(spacing: 0) {
            tabItem("Fjärr", icon: "appletvremote.gen4", activeIcon: "appletvremote.gen4.fill", selected: tab == .remote) {
                tab = .remote
            }
            tabItem("Inställningar", icon: "slider.horizontal.3", activeIcon: "slider.horizontal.3", selected: tab == .settings) {
                tab = .settings
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 66)
        .background {
            if scheme == .dark {
                Color.clear
            } else {
                Capsule().fill(palette.surfaceGlass)
                    .overlay(Capsule().stroke(palette.surfaceBorder, lineWidth: 1))
                    .shadow(color: Color(hex: 0x1E2832, opacity: 0.08), radius: 16, y: 10)
            }
        }
        .padding(.horizontal, scheme == .dark ? 10 : 15)
        .padding(.bottom, scheme == .dark ? 0 : 6)
    }

    private func tabItem(
        _ title: String, icon: String, activeIcon: String,
        selected: Bool, action: @escaping () -> Void
    ) -> some View {
        let palette = scheme.palette
        return Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: selected ? activeIcon : icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? palette.accentText : palette.tabInactive)
            .frame(maxWidth: .infinity)
            .frame(height: 59)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(palette.accentSubtle)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Handlingar

    private func toggleAppearance() {
        appearanceRaw = (scheme == .dark ? AppearanceMode.light : AppearanceMode.dark).rawValue
    }

    private func tap(_ key: TVKey) {
        if haptics && connection.ready { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        connection.press(key)
    }
}

// MARK: - Inställningar

@MainActor
struct SettingsScreen: View {
    @ObservedObject var connection: TVConnection
    @Binding var haptics: Bool
    @Binding var appearanceRaw: String
    var openPanel: (Panel) -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var showAppearance = false

    private var appearance: AppearanceMode { AppearanceMode(rawValue: appearanceRaw) ?? .system }

    var body: some View {
        let palette = scheme.palette
        ScrollView {
            VStack(spacing: 0) {
                Text("Inställningar")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(palette.textPrimary)
                    .frame(height: 56)

                Button { openPanel(.help) } label: {
                    HStack(spacing: 16) {
                        RabbitMark(size: 38, tint: palette.accent, accent: Color(hex: 0xE4F8E6))
                            .frame(width: 62, height: 62)
                            .background(
                                angledGradient(palette.tileStops, angle: 160),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.surfaceBorder, lineWidth: 1)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tech Rabbit Remote")
                                .font(.system(size: 24, weight: .bold))
                                .tracking(-0.4)
                                .foregroundStyle(palette.textPrimary)
                            Text("Din TV. Din kontroll.")
                                .font(.system(size: 16))
                                .foregroundStyle(palette.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 100)
                }
                .buttonStyle(.plain)
                .cardSurface(radius: 28)
                .padding(.top, 8)
                .accessibilityLabel("Tech Rabbit Remote, Din TV. Din kontroll.")

                VStack(spacing: 0) {
                    row(icon: "tv", title: "TV och anslutning", detail: connection.tvName) {
                        openPanel(.connection)
                    }
                    separator
                    row(icon: "questionmark.circle", title: "Hjälp", detail: "") {
                        openPanel(.help)
                    }
                    separator
                    HStack(spacing: 14) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 20))
                            .foregroundStyle(palette.iconPrimary)
                            .frame(width: 32)
                        Toggle("Knappvibration", isOn: $haptics)
                            .font(.system(size: 17))
                            .foregroundStyle(palette.textPrimary)
                            .tint(palette.success)
                    }
                    .padding(.leading, 18)
                    .padding(.trailing, 16)
                    .frame(height: 56)
                    separator
                    row(icon: "circle.lefthalf.filled", title: "Utseende", detail: appearance.title) {
                        showAppearance = true
                    }
                }
                .cardSurface(radius: 26)
                .padding(.top, 22)

                Text("v0.1.0 · Testversion")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
                    .padding(.top, 22)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showAppearance) {
            AppearanceView(appearanceRaw: $appearanceRaw)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(scheme.palette.separator)
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    private func row(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        let palette = scheme.palette
        return Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(palette.iconPrimary)
                    .frame(width: 32)
                Text(title)
                    .font(.system(size: 17))
                    .tracking(-0.2)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 8)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 16))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
            }
            .padding(.leading, 18)
            .padding(.trailing, 16)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(detail.isEmpty ? title : "\(title), \(detail)")
    }
}

// MARK: - Utseende

@MainActor
struct AppearanceView: View {
    @Binding var appearanceRaw: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = scheme.palette
        NavigationStack {
            ZStack {
                palette.sheet.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppearanceMode.allCases.enumerated()), id: \.element.id) { index, mode in
                            if index > 0 {
                                Rectangle().fill(palette.separator).frame(height: 1).padding(.leading, 18)
                            }
                            Button { appearanceRaw = mode.rawValue } label: {
                                HStack {
                                    Text(mode.title)
                                        .font(.system(size: 17))
                                        .foregroundStyle(palette.textPrimary)
                                    Spacer()
                                    if appearanceRaw == mode.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(palette.accentText)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 56)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(appearanceRaw == mode.rawValue ? .isSelected : [])
                        }
                    }
                    .cardSurface(radius: 26)

                    Text("Automatiskt följer telefonens inställning. Sol- och månknappen på fjärren växlar direkt mellan ljust och mörkt.")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.top, 14)
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.top, 12)
            }
            .navigationTitle("Utseende")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klart") { dismiss() }.foregroundStyle(palette.accentText)
                }
            }
        }
        .presentationDetents([.height(340), .large])
    }
}

// MARK: - Sifferknappar

@MainActor
struct NumberPadView: View {
    @ObservedObject var connection: TVConnection
    var haptics: Bool
    var openPanel: (Panel) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = scheme.palette
        NavigationStack {
            ZStack {
                palette.sheet.ignoresSafeArea()
                VStack(spacing: 12) {
                    if !connection.ready {
                        warningRow
                    }
                    NoticeBanner(connection: connection)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 8) {
                        ForEach(1...9, id: \.self) { number in
                            numberKey("\(number)", label: "Siffra \(number)") {
                                if let key = TVKey(rawValue: UInt64(number + 7)) { tap(key) }
                            }
                        }
                        Button { tap(.delete) } label: {
                            Image(systemName: "delete.left")
                                .font(.system(size: 24))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(GlassButtonStyle(radius: 18))
                        .accessibilityLabel("Radera")
                        numberKey("0", label: "Siffra 0") { tap(.zero) }
                        Button { tap(.ok) } label: {
                            Text("OK")
                                .font(.system(size: 21, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(GlassButtonStyle(radius: 18))
                        .accessibilityLabel("Bekräfta nummer")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 15)
                .padding(.top, 12)
            }
            .navigationTitle("Sifferknappar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klart") { dismiss() }.foregroundStyle(palette.accentText)
                }
            }
        }
        .presentationDetents([.height(464), .large])
    }

    private var warningRow: some View {
        let palette = scheme.palette
        return HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18))
                .foregroundStyle(palette.danger)
            Text("Inte ansluten. Siffran skickades inte.")
                .font(.system(size: 15))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 4)
            Button {
                dismiss()
                openPanel(.connection)
            } label: {
                Text("Anslut")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.connectText)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(
                        scheme == .dark ? palette.accentSubtle : Color(hex: 0xE3F5E8),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Anslut till TV")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(palette.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func numberKey(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 26))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(GlassButtonStyle(radius: 18))
        .accessibilityLabel(label)
    }

    private func tap(_ key: TVKey) {
        if haptics && connection.ready { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        connection.press(key)
    }
}
