import AppKit
import Foundation

enum AgentCommandOption: String, Codable, CaseIterable {
    case claude = "claude"
    case codex = "codex"
    case custom = "custom"

    var label: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .custom: "Custom"
        }
    }
}

enum TerminalApp: String, Codable, CaseIterable {
    case auto = "auto"
    case terminal = "Terminal"
    case iterm2 = "iTerm2"
    case warp = "Warp"
    case kitty = "Kitty"
    case alacritty = "Alacritty"
    case wezterm = "WezTerm"
    case hyper = "Hyper"

    var label: String {
        switch self {
        case .auto: "Auto Detect"
        case .terminal: "Terminal"
        case .iterm2: "iTerm2"
        case .warp: "Warp"
        case .kitty: "Kitty"
        case .alacritty: "Alacritty"
        case .wezterm: "WezTerm"
        case .hyper: "Hyper"
        }
    }

    var bundleID: String? {
        switch self {
        case .auto: nil
        case .terminal: "com.apple.Terminal"
        case .iterm2: "com.googlecode.iterm2"
        case .warp: "dev.warp.Warp-Stable"
        case .kitty: "net.kovidgoyal.kitty"
        case .alacritty: "org.alacritty"
        case .wezterm: "com.github.wez.wezterm"
        case .hyper: "co.zeit.hyper"
        }
    }

    var supportedModes: [TerminalOpenMode] {
        switch self {
        case .auto: [.window, .tab, .pane]
        case .terminal: [.window, .tab]
        case .iterm2: [.window, .tab, .pane]
        case .warp: [.window, .tab, .pane]
        case .kitty: [.window, .tab]
        case .alacritty: [.window]
        case .wezterm: [.window, .tab, .pane]
        case .hyper: [.window, .tab]
        }
    }

    static func detectInstalled() -> [TerminalApp] {
        var installed: [TerminalApp] = [.auto]
        for app in TerminalApp.allCases where app != .auto {
            if let bundleID = app.bundleID,
               NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
                installed.append(app)
            }
        }
        return installed
    }
}

enum TerminalOpenMode: String, Codable, CaseIterable {
    case window = "window"
    case tab = "tab"
    case pane = "pane"

    var label: String {
        switch self {
        case .window: "Window"
        case .tab: "Tab"
        case .pane: "Pane"
        }
    }
}

enum WorktreeDirectoryOption: String, Codable, CaseIterable {
    case dotWorktrees = ".worktrees"
    case claudeWorktrees = ".claude/worktrees"
    case homeWorktrees = "~/.worktrees"
    case custom = "custom"

    var label: String {
        switch self {
        case .dotWorktrees: ".worktrees"
        case .claudeWorktrees: ".claude/worktrees"
        case .homeWorktrees: "~/.worktrees"
        case .custom: "Custom"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var pollIntervalMinutes: Double = 2
    var showNotifications: Bool = true
    var notifyOnNewComments: Bool = true
    var notifyOnCheckComplete: Bool = true
    var notifyOnReviewSubmitted: Bool = true
    var agentCommandOption: AgentCommandOption = .claude
    var claudeCommand: String = "claude"
    var terminalApp: TerminalApp = .auto
    var terminalOpenMode: TerminalOpenMode = .window
    var worktreeDirectoryOption: WorktreeDirectoryOption = .dotWorktrees
    var customWorktreeDirectory: String = ""
    var unwatchedRepos: Set<String> = []
    var ignoredReviewers: Set<String> = []
    var localRepoPaths: [String: String] = [:]

    var effectiveCommand: String {
        switch agentCommandOption {
        case .claude: return "claude"
        case .codex: return "codex"
        case .custom: return claudeCommand
        }
    }

    var effectiveWorktreeDirectory: String {
        switch worktreeDirectoryOption {
        case .dotWorktrees: return ".worktrees"
        case .claudeWorktrees: return ".claude/worktrees"
        case .homeWorktrees: return "~/.worktrees"
        case .custom: return customWorktreeDirectory
        }
    }

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

    // Custom decoder for backward compatibility with old settings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle pollIntervalMinutes migration: old Int → new Double
        if let doubleVal = try? container.decode(Double.self, forKey: .pollIntervalMinutes) {
            pollIntervalMinutes = max(0.5, doubleVal)
        } else if let intVal = try? container.decode(Int.self, forKey: .pollIntervalMinutes) {
            pollIntervalMinutes = max(0.5, Double(intVal))
        }

        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? true
        notifyOnNewComments = try container.decodeIfPresent(Bool.self, forKey: .notifyOnNewComments) ?? true
        notifyOnCheckComplete = try container.decodeIfPresent(Bool.self, forKey: .notifyOnCheckComplete) ?? true
        notifyOnReviewSubmitted = try container.decodeIfPresent(Bool.self, forKey: .notifyOnReviewSubmitted) ?? true
        claudeCommand = try container.decodeIfPresent(String.self, forKey: .claudeCommand) ?? "claude"
        localRepoPaths = try container.decodeIfPresent([String: String].self, forKey: .localRepoPaths) ?? [:]

        // New fields with defaults
        agentCommandOption = try container.decodeIfPresent(AgentCommandOption.self, forKey: .agentCommandOption) ?? .claude
        terminalApp = try container.decodeIfPresent(TerminalApp.self, forKey: .terminalApp) ?? .auto
        terminalOpenMode = try container.decodeIfPresent(TerminalOpenMode.self, forKey: .terminalOpenMode) ?? .window
        worktreeDirectoryOption = try container.decodeIfPresent(WorktreeDirectoryOption.self, forKey: .worktreeDirectoryOption) ?? .dotWorktrees
        customWorktreeDirectory = try container.decodeIfPresent(String.self, forKey: .customWorktreeDirectory) ?? ""
        unwatchedRepos = try container.decodeIfPresent(Set<String>.self, forKey: .unwatchedRepos) ?? []
        ignoredReviewers = try container.decodeIfPresent(Set<String>.self, forKey: .ignoredReviewers) ?? []
    }

    init() {}
}
