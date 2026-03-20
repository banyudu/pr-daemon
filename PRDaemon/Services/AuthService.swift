import Foundation

@MainActor
class AuthService: ObservableObject {
    @Published var token: String?
    @Published var username: String?
    @Published var isAuthenticated = false
    @Published var error: String?

    private let tokenKey = "github_token"
    private let usernameKey = "github_username"

    init() {
        // Try stored token first
        if let stored = Keychain.load(key: tokenKey) {
            token = stored
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
            Keychain.save(key: tokenKey, value: newToken)
            UserDefaults.standard.set(user, forKey: usernameKey)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func logout() {
        token = nil
        username = nil
        isAuthenticated = false
        Keychain.delete(key: tokenKey)
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

    static func getGHToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/gh")
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

        // Try /usr/local/bin/gh as fallback
        let process2 = Process()
        process2.executableURL = URL(fileURLWithPath: "/usr/local/bin/gh")
        process2.arguments = ["auth", "token"]
        let pipe2 = Pipe()
        process2.standardOutput = pipe2
        process2.standardError = Pipe()

        do {
            try process2.run()
            process2.waitUntilExit()
            if process2.terminationStatus == 0 {
                let data = pipe2.fileHandleForReading.readDataToEndOfFile()
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

// Simple Keychain wrapper
enum Keychain {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.banyudu.pr-daemon",
            kSecAttrAccount: key,
            kSecValueData: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.banyudu.pr-daemon",
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.banyudu.pr-daemon",
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
