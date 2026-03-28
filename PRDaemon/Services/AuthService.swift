import Foundation

@MainActor
class AuthService: ObservableObject {
    @Published var token: String?
    @Published var username: String?
    @Published var isAuthenticated = false
    @Published var error: String?

    private let usernameKey = "github_username"

    init() {
        // Try gh CLI token on launch
        if let ghToken = Self.getGHToken() {
            token = ghToken
            username = UserDefaults.standard.string(forKey: usernameKey)
            isAuthenticated = true
        }
    }

    func tryGHCLI() async {
        if let ghToken = Self.getGHToken() {
            await setToken(ghToken)
        }
    }

    func setToken(_ newToken: String) async {
        error = nil
        do {
            let user = try await validateToken(newToken)
            token = newToken
            username = user
            isAuthenticated = true
            UserDefaults.standard.set(user, forKey: usernameKey)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logout() {
        token = nil
        username = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: usernameKey)
    }

    private func validateToken(_ token: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("pr-daemon", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AuthError.invalidToken
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let login = json?["login"] as? String else {
            throw AuthError.noUsername
        }
        return login
    }

    nonisolated static func ghPath() -> String? {
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"] {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    nonisolated static func isGHInstalled() -> Bool {
        ghPath() != nil
    }

    /// Check if `gh` is authenticated (logged in).
    nonisolated static func isGHAuthenticated() -> Bool {
        guard let path = ghPath() else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["auth", "status"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func isBrewInstalled() -> Bool {
        for path in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"] {
            if FileManager.default.fileExists(atPath: path) { return true }
        }
        return false
    }

    nonisolated static func brewPath() -> String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            return "/opt/homebrew/bin/brew"
        }
        return "/usr/local/bin/brew"
    }

    nonisolated static func getGHToken() -> String? {
        guard let path = ghPath() else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["auth", "token"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let token, !token.isEmpty { return token }
            }
        } catch {}

        return nil
    }
}

enum AuthError: LocalizedError {
    case invalidToken
    case noUsername

    var errorDescription: String? {
        switch self {
        case .invalidToken: "Invalid token or API error"
        case .noUsername: "Could not get username"
        }
    }
}

