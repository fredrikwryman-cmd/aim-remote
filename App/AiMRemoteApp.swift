import SwiftUI
import UIKit

@main
@MainActor
struct AiMRemoteApp: App {
    @StateObject private var connection = TVConnection()
    /// Utseendet ägs här och sätts i RemoteRoot, som är vyn som läser det.
    @AppStorage("tr.remote.theme") private var appearanceRaw = AppearanceMode.standard.rawValue
    @AppStorage("tr.remote.onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Startargument flyttas till appens egen domän, annars kan temat
        // aldrig ändras under en UI-testkörning.
        LaunchSeed.apply()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RemoteRoot(connection: connection, appearanceRaw: $appearanceRaw)
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
                connection.sceneBecameActive()
            }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    // Tillbaka på skärmen: anslut om till aktiv TV av sig själv.
                    connection.sceneBecameActive()
                case .background:
                    // Anslutningen behålls den stund iOS ger oss och stängs
                    // sedan snyggt. Inga omförsök medan appen ligger undan.
                    connection.sceneLeftForeground()
                default:
                    break
                }
            }
        }
    }
}
