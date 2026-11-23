import SwiftUI
import AiMCore
import UIKit

enum Panel: String, Identifiable {
    case connection, chooseTV, numbers, keyboard, help, appearance
    var id: String { rawValue }
}

enum MainTab { case remote, settings }

@MainActor
struct RemoteRoot: View {
    @ObservedObject var connection: TVConnection
    /// Utseendet ägs av AiMRemoteApp, som sätter preferredColorScheme. En egen
    /// @AppStorage här gjorde att skrivningen aldrig nådde dit.
    @Binding var appearanceRaw: String
    @AppStorage("tr.remote.haptics") private var haptics = true
    @State private var tab: MainTab = .remote
    @State private var panel: Panel?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            RemoteBackground(variant: .remote)

            Group {
                if tab == .remote {
                    RemoteScreen(connection: connection, appearanceRaw: $appearanceRaw) { open($0) }
                } else {
                    SettingsScreen(
                        connection: connection,
                        haptics: $haptics,
                        appearanceRaw: $appearanceRaw,
                        openPanel: { open($0) }
                    )
                }
            }
            .padding(.bottom, TR.Size.tabBar + TR.Size.tabBarBottom)

            FloatingTabBar(selection: $tab)
                .padding(.bottom, max(TR.Size.tabBarBottom - 34, 12))
        }
        .tint(TR.Colors.of(scheme).greenText)
        .overlay {
            if let panel {
                sheet(for: panel)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 24)),
                                removal: .opacity
                            )
                    )
            }
        }
        // Temabyte: crossfade 250 ms, direkt vid Reducera rorelse.
        .animation(reduceMotion ? nil : .easeInOut(duration: TR.Motion.themeSwap), value: appearanceRaw)
        .onChange(of: connection.ready) { ready in
            if ready { TRHaptics.connected() }
        }
        .onChange(of: connection.notice) { notice in
            if notice != nil { TRHaptics.error() }
        }
        // Widgetens yta oppnar techrabbit://remote. Da visas fjarrskarmen och
        // en oppen panel stangs.
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "techrabbit",
                  (url.host ?? url.lastPathComponent).lowercased() == "remote"
            else { return }
            close()
            tab = .remote
        }
    }

    @ViewBuilder
    private func sheet(for panel: Panel) -> some View {
        switch panel {
        case .connection:
            ConnectionPanel(connection: connection, onClose: close) { open($0) }
        case .chooseTV:
            ChooseTVPanel(connection: connection, onClose: close)
        case .numbers:
            NumberPadPanel(connection: connection, onClose: close) { open($0) }
        case .keyboard:
            KeyboardPanel(connection: connection, onClose: close)
        case .help:
            HelpPanel(onClose: close)
        case .appearance:
            AppearancePanel(appearanceRaw: $appearanceRaw, onClose: close)
        }
    }

    private func open(_ next: Panel) {
        if reduceMotion {
            panel = next
        } else {
            withAnimation(.easeOut(duration: TR.Motion.sheetIn)) { panel = next }
        }
    }

    private func close() {
        if reduceMotion {
            panel = nil
        } else {
            withAnimation(.easeOut(duration: TR.Motion.sheetOut)) { panel = nil }
        }
    }
}
