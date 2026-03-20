import SwiftUI

@main
struct PRDaemonApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var pollingService: PollingService
    @StateObject private var autoFixService: AutoFixService
    @StateObject private var updaterService = UpdaterService()

    init() {
        let auth = AuthService()
        _authService = StateObject(wrappedValue: auth)
        let polling = PollingService(authService: auth)
        let autoFix = AutoFixService(authService: auth)
        polling.autoFixService = autoFix
        _pollingService = StateObject(wrappedValue: polling)
        _autoFixService = StateObject(wrappedValue: autoFix)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(authService)
                .environmentObject(pollingService)
                .environmentObject(autoFixService)
                .environmentObject(updaterService)
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
