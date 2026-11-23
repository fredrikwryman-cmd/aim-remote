import SwiftUI
import AiMCore
import UIKit

enum Panel: String, Identifiable {
    case connection, chooseTV, numbers, keyboard, help
    var id: String { rawValue }
}

enum MainTab { case remote, settings }

@MainActor
struct RemoteRoot: View {
    @ObservedObject var connection: TVConnection
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
        // Appen följer telefonens ljusa eller mörka läge. Ingen temaknapp och
        // ingen Utseende-rad: inget preferredColorScheme sätts här.
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
