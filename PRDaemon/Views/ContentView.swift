import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var pollingService: PollingService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainView()
            } else {
                AuthView()
            }
        }
        .task {
            if !authService.isAuthenticated {
                await authService.tryGHCLI()
            }
            if authService.isAuthenticated {
                pollingService.startPolling()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                pollingService.startPolling()
            } else {
                pollingService.stopPolling()
            }
        }
    }
}
