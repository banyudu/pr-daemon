import Foundation

enum QuickActionService {
    static func openTerminalWithClaude(repoPath: String, context: String) {
        let settings = AppSettings.load()
        let cmd = settings.effectiveCommand
        let command = "cd '\(repoPath)' && \(cmd) '\(context)'"
        let mode = settings.terminalOpenMode

        switch settings.terminalApp {
        case .auto:
            runAppleScript(autoDetectScript(command: command, mode: mode))
        case .terminal:
            runAppleScript(terminalScript(command: command, mode: mode))
        case .iterm2:
            runAppleScript(iterm2Script(command: command, mode: mode))
        case .warp:
            runAppleScript(keystrokeTerminalScript(appName: "Warp", command: command, mode: mode))
        case .kitty:
            launchCLITerminal(executable: "kitty", command: command, mode: mode)
        case .alacritty:
            launchCLITerminal(executable: "alacritty", command: command, mode: mode)
        case .wezterm:
            launchCLITerminal(executable: "wezterm", command: command, mode: mode)
        case .hyper:
            runAppleScript(keystrokeTerminalScript(appName: "Hyper", command: command, mode: mode))
        }
    }

    static func runClaudeYolo(repoPath: String, prompt: String) async -> (success: Bool, output: String) {
        let settings = AppSettings.load()
        let cmd = settings.effectiveCommand

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [cmd, "--yolo", prompt]
        process.currentDirectoryURL = URL(fileURLWithPath: repoPath)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Script Runners

    private static func runAppleScript(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private static func launchCLITerminal(executable: String, command: String, mode: TerminalOpenMode) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        switch executable {
        case "kitty":
            switch mode {
            case .window:
                process.arguments = [executable, "--single-instance", "zsh", "-c", command]
            case .tab:
                process.arguments = [executable, "@", "launch", "--type=tab", "zsh", "-c", command]
            case .pane:
                process.arguments = [executable, "--single-instance", "zsh", "-c", command]
            }
        case "alacritty":
            process.arguments = [executable, "-e", "zsh", "-c", command]
        case "wezterm":
            switch mode {
            case .window:
                process.arguments = [executable, "start", "--", "zsh", "-c", command]
            case .tab:
                process.arguments = [executable, "cli", "spawn", "--new-tab", "--", "zsh", "-c", command]
            case .pane:
                process.arguments = [executable, "cli", "split-pane", "--", "zsh", "-c", command]
            }
        default:
            process.arguments = [executable, "-e", "zsh", "-c", command]
        }

        try? process.run()
    }

    // MARK: - Auto Detect

    private static func autoDetectScript(command: String, mode: TerminalOpenMode) -> String {
        """
        tell application "System Events"
            if exists (processes where name is "iTerm2") then
                \(iterm2Inner(command: command, mode: mode))
            else
                \(terminalInner(command: command, mode: mode))
            end if
        end tell
        """
    }

    // MARK: - iTerm2

    private static func iterm2Script(command: String, mode: TerminalOpenMode) -> String {
        """
        tell application "iTerm"
            activate
            \(iterm2Inner(command: command, mode: mode))
        end tell
        """
    }

    private static func iterm2Inner(command: String, mode: TerminalOpenMode) -> String {
        switch mode {
        case .window:
            return """
            tell application "iTerm"
                        create window with default profile
                        tell current session of current window
                            write text "\(command)"
                        end tell
                    end tell
            """
        case .tab:
            return """
            tell application "iTerm"
                        tell current window
                            create tab with default profile
                            tell current session
                                write text "\(command)"
                            end tell
                        end tell
                    end tell
            """
        case .pane:
            return """
            tell application "iTerm"
                        tell current session of current window
                            split vertically with default profile
                            tell last session of current tab of current window
                                write text "\(command)"
                            end tell
                        end tell
                    end tell
            """
        }
    }

    // MARK: - Terminal.app

    private static func terminalScript(command: String, mode: TerminalOpenMode) -> String {
        terminalInner(command: command, mode: mode)
    }

    private static func terminalInner(command: String, mode: TerminalOpenMode) -> String {
        switch mode {
        case .window, .pane:
            return """
            tell application "Terminal"
                        do script "\(command)"
                        activate
                    end tell
            """
        case .tab:
            return """
            tell application "Terminal"
                        activate
                        tell application "System Events" to keystroke "t" using command down
                        delay 0.3
                        do script "\(command)" in front window
                    end tell
            """
        }
    }

    // MARK: - Keystroke-based terminals (Warp, Hyper)

    private static func keystrokeTerminalScript(appName: String, command: String, mode: TerminalOpenMode) -> String {
        let shortcut: String
        switch mode {
        case .window: shortcut = "keystroke \"n\" using command down"
        case .tab: shortcut = "keystroke \"t\" using command down"
        case .pane: shortcut = "keystroke \"d\" using command down"
        }

        return """
        tell application "\(appName)"
            activate
        end tell
        delay 0.3
        tell application "System Events"
            tell process "\(appName)"
                \(shortcut)
                delay 0.3
                keystroke "\(command)"
                key code 36
            end tell
        end tell
        """
    }
}
