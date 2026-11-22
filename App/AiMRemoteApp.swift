import SwiftUI
import UIKit

@main
@MainActor
struct AiMRemoteApp: App {
    @StateObject private var connection = TVConnection()
    @AppStorage("tr.remote.theme") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("tr.remote.onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RemoteRoot(connection: connection)
                    .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
                if !onboarded {
                    // R01 visas bara vid första start och är alltid mörk.
                    StartView {
                        if UIAccessibility.isReduceMotionEnabled {
                            onboarded = true
                        } else {
                            withAnimation(.easeOut(duration: TR.Motion.themeSwap)) { onboarded = true }
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .task {
                // Återanslutningen startar direkt, oavsett startskärmen.
                connection.reconnectIfSaved()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background { connection.disconnect() }
                if phase == .active { connection.reconnectIfSaved() }
            }
        }
    }
}
