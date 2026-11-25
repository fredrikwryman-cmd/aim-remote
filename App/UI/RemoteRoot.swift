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
    /// Kort entré när appen kommer fram igen (punkt 17).
    @State private var entered = true
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            // Flikbyte: korsövergång 160 ms med 8 pt glidning uppåt (punkt 15).
            ZStack {
                if tab == .remote {
                    RemoteScreen(connection: connection) { open($0) }
                        .transition(tabTransition)
                } else {
                    SettingsScreen(
                        connection: connection,
                        haptics: $haptics,
                        appearanceRaw: $appearanceRaw,
                        openPanel: { open($0) }
                    )
                    .transition(tabTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, TR.Size.tabBar + 10)

            FloatingTabBar(selection: $tab)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Fjärren bakom en öppen panel sjunker (punkt 7), och entrén börjar
        // strax över full storlek (punkt 17). Bakgrunden ligger utanför och
        // skalas inte, så inga kanter blottas.
        .scaleEffect(contentScale)
        .opacity(entered ? 1 : 0)
        .animation(TRMotion.spring(reduceMotion, TRMotion.smooth), value: panel)
        // Bakgrunden ligger bakom innehållet i stället för bredvid det i
        // stacken. En syskonvy med ignoresSafeArea drar ut hela stacken, och
        // då hamnade rubriken under statusfältet.
        .background(RemoteBackground())
        .tint(TR.Colors.of(scheme).accentText)
        // Panelen växer ur den knapp som öppnade den. Knapparna märks med
        // panelSource(_:), och deras läge läses här.
        .overlayPreferenceValue(PanelOriginKey.self) { anchors in
            GeometryReader { proxy in
                if let panel {
                    sheet(for: panel)
                        .environment(\.panelOrigin, origin(of: panel, anchors, proxy))
                        .transition(.opacity)
                }
            }
        }
        // Utseendet sätts här, i vyn som läser värdet. Låg det i App-kroppen
        // räknades skrivningen aldrig om till ett nytt colorScheme.
        .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
        // Byte av utseende: korsövergång, direkt vid Reducera rörelse.
        .animation(reduceMotion ? nil : .easeInOut(duration: TRMotion.theme),
                   value: appearanceRaw)
        .onChange(of: connection.ready) { ready in
            if ready { TRHaptics.connected() }
        }
        .onChange(of: connection.notice) { notice in
            if notice != nil { TRHaptics.error() }
        }
        .onAppear { playEntrance() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { playEntrance() }
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

    private var contentScale: CGFloat {
        if reduceMotion { return 1 }
        if panel != nil { return TRMotion.recedeScale }
        return entered ? 1 : TRMotion.entranceScale
    }

    private var tabTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: AnyTransition.opacity.combined(with: .offset(y: 8)),
            removal: .opacity
        )
    }

    /// Knappens mitt, uttryckt som en punkt i skärmens ruta.
    private func origin(of panel: Panel,
                        _ anchors: [String: Anchor<CGRect>],
                        _ proxy: GeometryProxy) -> UnitPoint {
        guard let anchor = anchors[panel.id] else { return .center }
        let size = proxy.size
        guard size.width > 0, size.height > 0 else { return .center }
        let rect = proxy[anchor]
        return UnitPoint(x: min(max(rect.midX / size.width, 0), 1),
                         y: min(max(rect.midY / size.height, 0), 1))
    }

    private func playEntrance() {
        guard !reduceMotion else {
            entered = true
            return
        }
        entered = false
        // Nollstallningen och entren maste ligga i tva olika uppdateringar,
        // annars ser SwiftUI bara slutlaget och ingen rorelse blir av.
        Task { @MainActor in
            withAnimation(.easeOut(duration: TRMotion.entrance)) { entered = true }
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
        TRHaptics.soft()
        if reduceMotion {
            panel = next
        } else {
            withAnimation(.easeOut(duration: TRMotion.swap)) { panel = next }
        }
    }

    private func close() {
        if reduceMotion {
            panel = nil
        } else {
            withAnimation(.easeIn(duration: TRMotion.sheetOut)) { panel = nil }
        }
    }
}
