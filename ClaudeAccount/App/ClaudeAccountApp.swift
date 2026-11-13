import SwiftUI
import SwiftData

@main
struct ClaudeAccountApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [ClaudeAccount.self, SubscriptionRecord.self])
        .defaultSize(width: 1000, height: 700)
    }
}

struct RootView: View {
    @ObservedObject private var crypto = CryptoService.shared

    var body: some View {
        Group {
            if crypto.isUnlocked {
                ContentView()
            } else {
                LockView()
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
