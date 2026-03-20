import Foundation
import UserNotifications

struct FixResult: Identifiable {
    let id = UUID()
    let threadId: String
    let prNumber: Int
    let success: Bool
    let message: String
}

@MainActor
class AutoFixService: ObservableObject {
    @Published var activeFixCount = 0
    @Published var fixResults: [FixResult] = []

    private let maxConcurrent = 3
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func processNewAIThreads(old: [PullRequest], new: [PullRequest]) async {
        let settings = AppSettings.load()
        guard settings.autoFixAIReviews else { return }

        let oldThreadIds = Set(old.flatMap { $0.reviewThreads.map(\.id) })
        var threadsToFix: [(pr: PullRequest, thread: ReviewThread)] = []

        for pr in new {
            for thread in pr.unresolvedThreads where !oldThreadIds.contains(thread.id) {
                threadsToFix.append((pr, thread))
            }
        }

        guard !threadsToFix.isEmpty else { return }

        // Process with concurrency limit
        for batch in threadsToFix.chunked(maxSize: maxConcurrent) {
            await withTaskGroup(of: FixResult.self) { group in
                for (pr, thread) in batch {
                    activeFixCount += 1
                    group.addTask { [self] in
                        await self.fixThread(pr: pr, thread: thread)
                    }
                }

                for await result in group {
                    activeFixCount -= 1
                    fixResults.append(result)
                }
            }
        }

        // Send summary notification
        let succeeded = fixResults.suffix(threadsToFix.count).filter(\.success).count
        if succeeded > 0 {
            let content = UNMutableNotificationContent()
            content.title = "Auto-fix Complete"
            content.body = "Fixed \(succeeded)/\(threadsToFix.count) AI review comments"
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func fixThread(pr: PullRequest, thread: ReviewThread) async -> FixResult {
        let settings = AppSettings.load()
        let repoPath = settings.localRepoPaths[pr.repo] ?? ""

        guard !repoPath.isEmpty else {
            return FixResult(threadId: thread.id, prNumber: pr.number, success: false,
                             message: "No local repo path configured for \(pr.repo)")
        }

        let prompt = buildFixPrompt(pr: pr, thread: thread)
        let result = await QuickActionService.runClaudeYolo(repoPath: repoPath, prompt: prompt)

        if result.success {
            // Try to resolve the thread on GitHub
            if let token = authService.token {
                let client = GitHubClient(token: token)
                try? await client.resolveReviewThread(threadId: thread.id)
            }
        }

        return FixResult(threadId: thread.id, prNumber: pr.number,
                         success: result.success, message: result.output)
    }

    private func buildFixPrompt(pr: PullRequest, thread: ReviewThread) -> String {
        var parts: [String] = ["Fix AI review comment on PR #\(pr.number): \(pr.title)"]

        if let path = thread.path {
            var loc = "File: \(path)"
            if let line = thread.line { loc += ":\(line)" }
            parts.append(loc)
        }

        if let comment = thread.comments.first {
            parts.append("Review comment from @\(comment.author):\n\(String(comment.body.prefix(500)))")
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Array chunking helper

private extension Array {
    func chunked(maxSize: Int) -> [[Element]] {
        stride(from: 0, to: count, by: maxSize).map {
            Array(self[$0..<Swift.min($0 + maxSize, count)])
        }
    }
}
