import SwiftUI

@main
struct PRDaemonApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var pollingService: PollingService

    init() {
        let auth = AuthService()
        _authService = StateObject(wrappedValue: auth)
        _pollingService = StateObject(wrappedValue: PollingService(authService: auth))
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(authService)
                .environmentObject(pollingService)
                .frame(width: 400, height: 580)
        } label: {
            Label("PR Daemon", systemImage: trayIconName)
        }
        .menuBarExtraStyle(.window)
    }

    private var trayIconName: String {
        let hasAttention = pollingService.pullRequests.contains { $0.needsAttention }
        return hasAttention ? "arrow.triangle.pull" : "arrow.triangle.pull"
    }
}
