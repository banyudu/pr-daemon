import Foundation

struct AppSettings: Codable {
    var pollIntervalMinutes: Int = 3
    var showNotifications: Bool = true
    var notifyOnNewComments: Bool = true
    var notifyOnCheckComplete: Bool = true
    var notifyOnReviewSubmitted: Bool = true
    var claudeCommand: String = "claude"
    var localRepoPaths: [String: String] = [:]

    static let storageKey = "appSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
