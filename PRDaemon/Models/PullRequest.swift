import Foundation

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
}

struct PRSnapshot {
    let checkStatus: CheckStatus
    let reviewState: ReviewState
    let commentCount: Int
}

struct PRChange {
    let prNumber: Int
    let prTitle: String
    let repo: String
    let changeType: String
    let message: String
}
