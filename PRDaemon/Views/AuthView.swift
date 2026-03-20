import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var token = ""
    @State private var isLoading = false
    @State private var ghInstalled = AuthService.isGHInstalled()
    @State private var isInstallingGH = false
    @State private var installOutput = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("PR Daemon")
                    .font(.system(size: 16, weight: .semibold))

                Text("Enter a GitHub token with **repo** scope, or authenticate via the `gh` CLI.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                if !ghInstalled {
                    ghInstallBanner
                }

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

    private var ghInstallBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
                Text("GitHub CLI (`gh`) not found")
                    .font(.system(size: 12, weight: .medium))
            }

            Text("Install `gh` to auto-authenticate and avoid managing tokens manually.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if isInstallingGH {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            } else if !installOutput.isEmpty {
                Text(installOutput)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(installOutput.contains("successfully") || installOutput.contains("installed") ? .green : .red)
                    .lineLimit(3)
            }

            if !isInstallingGH {
                HStack(spacing: 8) {
                    if AuthService.isBrewInstalled() {
                        Button("Install via Homebrew") {
                            installGH(method: .brew)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button("Install via Script") {
                        installGH(method: .script)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.orange.opacity(0.3)))
    }

    private enum InstallMethod {
        case brew, script
    }

    private func installGH(method: InstallMethod) {
        isInstallingGH = true
        installOutput = ""

        Task.detached {
            let brewPath = await AuthService.brewPath()
            let process = Process()
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            switch method {
            case .brew:
                process.executableURL = URL(fileURLWithPath: brewPath)
                process.arguments = ["install", "gh"]
            case .script:
                // GitHub's official install script via conda-forge/gh releases
                // Use the recommended approach: download the macOS pkg
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [
                    "zsh", "-c",
                    """
                    set -e
                    TMPDIR=$(mktemp -d)
                    ARCH=$(uname -m)
                    if [ "$ARCH" = "arm64" ]; then
                        PKG_ARCH="arm64"
                    else
                        PKG_ARCH="amd64"
                    fi
                    VERSION=$(curl -sL https://api.github.com/repos/cli/cli/releases/latest | grep '"tag_name"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
                    curl -sL "https://github.com/cli/cli/releases/download/v${VERSION}/gh_${VERSION}_macOS_${PKG_ARCH}.pkg" -o "$TMPDIR/gh.pkg"
                    sudo installer -pkg "$TMPDIR/gh.pkg" -target /
                    rm -rf "$TMPDIR"
                    echo "gh installed successfully"
                    """
                ]
            }

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                await MainActor.run {
                    isInstallingGH = false
                    if process.terminationStatus == 0 {
                        installOutput = "gh installed successfully!"
                        ghInstalled = AuthService.isGHInstalled()
                        // Auto-try gh auth after install
                        Task {
                            await authService.tryGHCLI()
                        }
                    } else {
                        installOutput = output.isEmpty ? "Installation failed" : String(output.suffix(200))
                    }
                }
            } catch {
                await MainActor.run {
                    isInstallingGH = false
                    installOutput = error.localizedDescription
                }
            }
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
