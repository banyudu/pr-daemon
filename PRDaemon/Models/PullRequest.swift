import Foundation

enum AIReviewer: String, CaseIterable, Codable {
    case greptile = "greptile-apps"
    case devin = "devin-ai-integration"
    case coderabbit = "coderabbitai"
    case cursorBot = "cursor-bot"
    case codex = "openai-codex"

    var displayName: String {
        switch self {
        case .greptile: "Greptile"
        case .devin: "Devin"
        case .coderabbit: "CodeRabbit"
        case .cursorBot: "Cursor Bot"
        case .codex: "Codex"
        }
    }

    static func isAIReviewer(_ login: String) -> Bool {
        let known = Set(AppSettings.load().knownAIReviewers)
        return known.contains(login)
    }
}

struct ReviewThread: Identifiable, Codable {
    let id: String
    let isResolved: Bool
    let path: String?
    let line: Int?
    let comments: [ReviewComment]
}

struct ReviewComment: Identifiable, Codable {
    let id: String
    let author: String
    let body: String
    let createdAt: Date
    let url: String
}

struct AIReviewMetadata {
    let reviewer: AIReviewer?
    let confidence: Double?
    let severity: String?
}

enum CheckStatus: String, Codable, CaseIterable {
    case pending, running, success, failure, neutral

    var label: String {
        switch self {
        case .pending: "Pending"
        case .running: "Running"
        case .success: "Passed"
        case .failure: "Failed"
        case .neutral: "Neutral"
        }
    }

    var color: String {
        switch self {
        case .success: "green"
        case .failure: "red"
        case .running: "yellow"
        case .pending: "gray"
        case .neutral: "gray"
        }
    }
}

enum ReviewState: String, Codable, CaseIterable {
    case approved, changesRequested, commented, pending, dismissed

    var label: String {
        switch self {
        case .approved: "Approved"
        case .changesRequested: "Changes Requested"
        case .commented: "Commented"
        case .pending: "Review Pending"
        case .dismissed: "Dismissed"
        }
    }
}

struct PRCheck: Identifiable, Codable {
    var id: String { name }
    let name: String
    let status: CheckStatus
    let url: String?
    let completedAt: String?
}

struct PRReview: Identifiable, Codable {
    var id: String { "\(author)-\(submittedAt)" }
    let author: String
    let state: ReviewState
    let submittedAt: String
    let body: String?
}

struct PRComment: Identifiable, Codable {
    let id: String
    let author: String
    let body: String
    let createdAt: Date
    let url: String
}

struct PullRequest: Identifiable, Codable {
    let id: String
    let number: Int
    let title: String
    let url: String
    let repo: String
    let repoURL: String
    let branch: String
    let baseBranch: String
    let isDraft: Bool
    let createdAt: Date
    let updatedAt: Date
    let checks: [PRCheck]
    let reviews: [PRReview]
    let commentCount: Int
    let latestComments: [PRComment]
    let overallCheckStatus: CheckStatus
    let overallReviewState: ReviewState
    let reviewThreads: [ReviewThread]

    var needsAttention: Bool {
        filteredCheckStatus == .failure ||
        filteredReviewState == .changesRequested ||
        filteredCommentCount > 0
    }

    // MARK: - Filtered by ignored reviewers

    private var ignoredReviewers: Set<String> {
        AppSettings.load().ignoredReviewers
    }

    var filteredChecks: [PRCheck] {
        let ignored = ignoredReviewers
        if ignored.isEmpty { return checks }
        return checks.filter { check in
            !ignored.contains(where: { check.name.localizedCaseInsensitiveContains($0) })
        }
    }

    var filteredReviews: [PRReview] {
        let ignored = ignoredReviewers
        if ignored.isEmpty { return reviews }
        return reviews.filter { !ignored.contains($0.author) }
    }

    var filteredComments: [PRComment] {
        let ignored = ignoredReviewers
        if ignored.isEmpty { return latestComments }
        return latestComments.filter { !ignored.contains($0.author) }
    }

    var filteredCommentCount: Int {
        let ignored = ignoredReviewers
        if ignored.isEmpty { return commentCount }
        return commentCount - latestComments.filter { ignored.contains($0.author) }.count
    }

    var filteredCheckStatus: CheckStatus {
        let checks = filteredChecks
        if checks.isEmpty { return .pending }
        if checks.contains(where: { $0.status == .failure }) { return .failure }
        if checks.contains(where: { $0.status == .running }) { return .running }
        if checks.allSatisfy({ $0.status == .success || $0.status == .neutral }) { return .success }
        return .pending
    }

    var filteredReviewState: ReviewState {
        let reviews = filteredReviews
        if reviews.isEmpty { return overallReviewState }
        if reviews.contains(where: { $0.state == .changesRequested }) { return .changesRequested }
        if reviews.contains(where: { $0.state == .approved }) { return .approved }
        return overallReviewState
    }

    // MARK: - AI Review helpers

    var unresolvedThreads: [ReviewThread] {
        let known = AppSettings.load().knownAIReviewers
        return reviewThreads.filter { thread in
            !thread.isResolved &&
            thread.comments.contains { AIReviewer.isAIReviewer($0.author) || known.contains($0.author) }
        }
    }

    var unresolvedAIThreadCount: Int { unresolvedThreads.count }

    var aiReviews: [PRReview] {
        reviews.filter { AIReviewer.isAIReviewer($0.author) }
    }
}

struct PRSnapshot {
    let checkStatus: CheckStatus
    let reviewState: ReviewState
    let commentCount: Int
    let unresolvedThreadIds: Set<String>
}

struct PRChange {
    let prNumber: Int
    let prTitle: String
    let repo: String
    let changeType: String
    let message: String
}
