import Foundation

enum QuickActionService {
    static func openTerminalWithClaude(repoPath: String, context: String) {
        let settings = AppSettings.load()
        let cmd = settings.claudeCommand

        let script = """
        tell application "System Events"
            if exists (processes where name is "iTerm2") then
                tell application "iTerm"
                    create window with default profile
                    tell current session of current window
                        write text "cd '\(repoPath)' && \(cmd) '\(context)'"
                    end tell
                end tell
            else
                tell application "Terminal"
                    do script "cd '\(repoPath)' && \(cmd) '\(context)'"
                    activate
                end tell
            end if
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    static func runClaudeYolo(repoPath: String, prompt: String) async -> (success: Bool, output: String) {
        let settings = AppSettings.load()
        let cmd = settings.claudeCommand

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
}
