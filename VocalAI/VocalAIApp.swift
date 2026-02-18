import SwiftUI

@main
struct VocalAIApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ConversationView()
                .environment(appState)
        }
    }
}
