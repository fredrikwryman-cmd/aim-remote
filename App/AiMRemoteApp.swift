import SwiftUI

@main
@MainActor
struct AiMRemoteApp: App {
    @StateObject private var connection = TVConnection()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RemoteRoot(connection: connection)
                .preferredColorScheme(.dark)
                .task { connection.reconnectIfSaved() }
                .onChange(of: scenePhase) { phase in
                    if phase == .background { connection.disconnect() }
                    if phase == .active { connection.reconnectIfSaved() }
                }
        }
    }
}
