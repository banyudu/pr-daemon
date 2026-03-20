import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var token = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("PR Daemon")
                    .font(.system(size: 16, weight: .semibold))

                Text("Enter a GitHub token with **repo** scope, or authenticate via the `gh` CLI.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                SecureField("ghp_xxxxxxxxxxxx", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                if let error = authService.error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }

                Button(action: submit) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isLoading ? "Authenticating..." : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(24)

            Spacer()
        }
    }

    private func submit() {
        isLoading = true
        Task {
            await authService.setToken(token.trimmingCharacters(in: .whitespaces))
            isLoading = false
        }
    }
}
