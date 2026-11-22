import SwiftUI
import UIKit

@main
@MainActor
struct AiMRemoteApp: App {
    @StateObject private var connection = TVConnection()
    @AppStorage("appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var launching = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RemoteRoot(connection: connection)
                if launching {
                    LaunchView { endLaunch() }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(AppearanceMode(rawValue: appearanceRaw)?.colorScheme)
            .task {
                // Återanslutningen startar direkt. Startskärmen ligger bara ovanpå.
                connection.reconnectIfSaved()
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                endLaunch()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background { connection.disconnect() }
                if phase == .active { connection.reconnectIfSaved() }
            }
        }
    }

    private func endLaunch() {
        guard launching else { return }
        if UIAccessibility.isReduceMotionEnabled {
            launching = false
        } else {
            withAnimation(.easeOut(duration: 0.35)) { launching = false }
        }
    }
}
