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
    @AppStorage("tr.remote.haptics") private var haptics = true
    @AppStorage("tr.remote.theme") private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var tab: MainTab = .remote
    @State private var panel: Panel?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .bottom) {
            RemoteBackground(variant: .remote)
            Group {
                if tab == .remote {
                    RemoteScreen(connection: connection, appearanceRaw: $appearanceRaw) { panel = $0 }
                } else {
                    SettingsScreen(
                        connection: connection,
                        haptics: $haptics,
                        appearanceRaw: $appearanceRaw,
                        openPanel: { panel = $0 }
                    )
                }
            }
            .padding(.bottom, TR.Size.tabBar + TR.Size.tabBarBottom)

            FloatingTabBar(selection: $tab)
                .padding(.bottom, max(TR.Size.tabBarBottom - 34, 12))
        }
        .tint(TR.Colors.of(scheme).greenText)
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
                get: { connection.notice != nil && panel == nil && tab == .settings },
                set: { if !$0 { connection.notice = nil } }
            )
        ) {
            Button("OK") { connection.notice = nil }
        } message: { Text(connection.notice ?? "") }
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
                        TRSymbol(width: 38)
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
