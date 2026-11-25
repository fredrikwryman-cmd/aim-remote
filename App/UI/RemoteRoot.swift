import SwiftUI
import AiMCore
import UIKit

enum Panel: String, Identifiable {
    case connection, chooseTV, numbers, keyboard, help, appearance, log
    var id: String { rawValue }
}

enum MainTab { case remote, settings }

@MainActor
struct RemoteRoot: View {
    @ObservedObject var connection: TVConnection
    /// Utseendet ägs av AiMRemoteApp, som skickar bindningen hit. En egen
    /// @AppStorage här gjorde att skrivningen aldrig nådde preferredColorScheme.
    @Binding var appearanceRaw: String
    @AppStorage("tr.remote.haptics") private var haptics = true
    @State private var tab: MainTab = .remote
    @State private var panel: Panel?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if tab == .remote {
                    RemoteScreen(connection: connection) { open($0) }
                } else {
                    SettingsScreen(
                        connection: connection,
                        haptics: $haptics,
                        appearanceRaw: $appearanceRaw,
                        openPanel: { open($0) }
                    )
                }
            }
            .padding(.bottom, TR.Size.tabBar + 10)

            FloatingTabBar(selection: $tab)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Bakgrunden ligger bakom innehållet i stället för bredvid det i
        // stacken. En syskonvy med ignoresSafeArea drar ut hela stacken, och
        // då hamnade rubriken under statusfältet.
        .background(RemoteBackground())
        .tint(TR.Colors.of(scheme).accentText)
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
        // Utseendet sätts här, i vyn som läser värdet. Låg det i App-kroppen
        // räknades skrivningen aldrig om till ett nytt colorScheme.
        .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        // Byte av utseende: korsövergång 250 ms, direkt vid Reducera rörelse.
        .animation(reduceMotion ? nil : .easeInOut(duration: TR.Motion.themeSwap),
                   value: appearanceRaw)
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
            HelpPanel(onClose: close) { open($0) }
        case .log:
            ConnectionLogPanel(onClose: close)
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
