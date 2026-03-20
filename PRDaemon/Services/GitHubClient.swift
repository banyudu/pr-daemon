import Foundation

class GitHubClient {
    private let token: String

    init(token: String) {
        self.token = token
    }

    func fetchMyPRs() async throws -> [PullRequest] {
        let query = "is:pr is:open author:@me sort:updated-desc"
        let body: [String: Any] = [
            "query": Self.graphQLQuery,
            "variables": ["query": query],
        ]

        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("pr-daemon", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.apiError(text)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let errors = json?["errors"] as? [[String: Any]] {
            let messages = errors.compactMap { $0["message"] as? String }
            throw GitHubError.graphQLError(messages.joined(separator: ", "))
        }

        guard let searchData = (json?["data"] as? [String: Any])?["search"] as? [String: Any],
              let nodes = searchData["nodes"] as? [[String: Any]]
        else {
            throw GitHubError.parseError
        }

        return nodes.compactMap { Self.parsePRNode($0) }
    }

    // MARK: - Parsing

    private static func parsePRNode(_ node: [String: Any]) -> PullRequest? {
        guard let id = node["id"] as? String,
              let number = node["number"] as? Int,
              let title = node["title"] as? String,
              let url = node["url"] as? String,
              let repo = (node["repository"] as? [String: Any])?["nameWithOwner"] as? String,
              let repoURL = (node["repository"] as? [String: Any])?["url"] as? String,
              let stateStr = node["state"] as? String
        else { return nil }

        let isDraft = node["isDraft"] as? Bool ?? false
        let branch = node["headRefName"] as? String ?? ""
        let baseBranch = node["baseRefName"] as? String ?? ""
        let createdAt = parseDate(node["createdAt"] as? String)
        let updatedAt = parseDate(node["updatedAt"] as? String)

        let reviews = parseReviews(node["reviews"] as? [String: Any])
        let (commentCount, latestComments) = parseComments(node["comments"] as? [String: Any])
        let checks = parseChecks(node["commits"] as? [String: Any])
        let overallCheckStatus = parseOverallCheckStatus(node["commits"] as? [String: Any])
        let overallReviewState = parseReviewDecision(node["reviewDecision"] as? String)
        let reviewThreads = parseReviewThreads(node["reviewThreads"] as? [String: Any])

        guard stateStr == "OPEN" || stateStr == "MERGED" || stateStr == "CLOSED" else { return nil }

        return PullRequest(
            id: id, number: number, title: title, url: url,
            repo: repo, repoURL: repoURL,
            branch: branch, baseBranch: baseBranch,
            isDraft: isDraft,
            createdAt: createdAt, updatedAt: updatedAt,
            checks: checks, reviews: reviews,
            commentCount: commentCount, latestComments: latestComments,
            overallCheckStatus: overallCheckStatus,
            overallReviewState: overallReviewState,
            reviewThreads: reviewThreads
        )
    }

    private static func parseDate(_ str: String?) -> Date {
        guard let str else { return .now }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: str) ?? ISO8601DateFormatter().date(from: str) ?? .now
    }

    private static func parseReviews(_ data: [String: Any]?) -> [PRReview] {
        guard let nodes = data?["nodes"] as? [[String: Any]] else { return [] }
        return nodes.compactMap { node in
            let author = (node["author"] as? [String: Any])?["login"] as? String ?? ""
            let stateStr = node["state"] as? String ?? ""
            let submittedAt = node["submittedAt"] as? String ?? ""
            let body = node["body"] as? String
            let state: ReviewState = switch stateStr {
            case "APPROVED": .approved
            case "CHANGES_REQUESTED": .changesRequested
            case "COMMENTED": .commented
            case "DISMISSED": .dismissed
            default: .pending
            }
            return PRReview(author: author, state: state, submittedAt: submittedAt, body: body)
        }
    }

    private static func parseReviewThreads(_ data: [String: Any]?) -> [ReviewThread] {
        guard let nodes = data?["nodes"] as? [[String: Any]] else { return [] }
        return nodes.compactMap { node in
            guard let id = node["id"] as? String else { return nil }
            let isResolved = node["isResolved"] as? Bool ?? false
            let path = node["path"] as? String
            let line = node["line"] as? Int
            let commentsData = node["comments"] as? [String: Any]
            let commentNodes = commentsData?["nodes"] as? [[String: Any]] ?? []
            let comments = commentNodes.compactMap { cNode -> ReviewComment? in
                guard let cId = cNode["id"] as? String,
                      let body = cNode["body"] as? String,
                      let url = cNode["url"] as? String
                else { return nil }
                let author = (cNode["author"] as? [String: Any])?["login"] as? String ?? ""
                let createdAt = parseDate(cNode["createdAt"] as? String)
                return ReviewComment(id: cId, author: author, body: body, createdAt: createdAt, url: url)
            }
            return ReviewThread(id: id, isResolved: isResolved, path: path, line: line, comments: comments)
        }
    }

    private static func parseComments(_ data: [String: Any]?) -> (Int, [PRComment]) {
        guard let data else { return (0, []) }
        let count = data["totalCount"] as? Int ?? 0
        let nodes = data["nodes"] as? [[String: Any]] ?? []
        let comments = nodes.compactMap { node -> PRComment? in
            guard let id = node["id"] as? String,
                  let body = node["body"] as? String,
                  let url = node["url"] as? String
            else { return nil }
            let author = (node["author"] as? [String: Any])?["login"] as? String ?? ""
            let createdAt = parseDate(node["createdAt"] as? String)
            return PRComment(id: id, author: author, body: body, createdAt: createdAt, url: url)
        }
        return (count, comments)
    }

    private static func parseChecks(_ commits: [String: Any]?) -> [PRCheck] {
        guard let nodes = commits?["nodes"] as? [[String: Any]],
              let commitNode = nodes.first,
              let commit = commitNode["commit"] as? [String: Any],
              let rollup = commit["statusCheckRollup"] as? [String: Any],
              let contexts = rollup["contexts"] as? [String: Any],
              let contextNodes = contexts["nodes"] as? [[String: Any]]
        else { return [] }

        return contextNodes.compactMap { node in
            let typename = node["__typename"] as? String
            if typename == "CheckRun" {
                let name = node["name"] as? String ?? ""
                let status = node["status"] as? String ?? ""
                let conclusion = node["conclusion"] as? String
                let url = node["detailsUrl"] as? String
                let completedAt = node["completedAt"] as? String
                return PRCheck(
                    name: name,
                    status: parseCheckRunStatus(status, conclusion: conclusion),
                    url: url, completedAt: completedAt
                )
            } else if typename == "StatusContext" {
                let name = node["context"] as? String ?? ""
                let state = node["state"] as? String ?? ""
                let url = node["targetUrl"] as? String
                let status: CheckStatus = switch state {
                case "SUCCESS": .success
                case "FAILURE", "ERROR": .failure
                case "PENDING", "EXPECTED": .pending
                default: .neutral
                }
                return PRCheck(name: name, status: status, url: url, completedAt: nil)
            }
            return nil
        }
    }

    private static func parseCheckRunStatus(_ status: String, conclusion: String?) -> CheckStatus {
        switch status {
        case "COMPLETED":
            switch conclusion {
            case "SUCCESS": return .success
            case "FAILURE", "TIMED_OUT", "CANCELLED": return .failure
            default: return .neutral
            }
        case "IN_PROGRESS": return .running
        default: return .pending
        }
    }

    private static func parseOverallCheckStatus(_ commits: [String: Any]?) -> CheckStatus {
        guard let nodes = commits?["nodes"] as? [[String: Any]],
              let commitNode = nodes.first,
              let commit = commitNode["commit"] as? [String: Any],
              let rollup = commit["statusCheckRollup"] as? [String: Any],
              let state = rollup["state"] as? String
        else { return .pending }

        return switch state {
        case "SUCCESS": .success
        case "FAILURE", "ERROR": .failure
        case "PENDING": .pending
        default: .running
        }
    }

    private static func parseReviewDecision(_ decision: String?) -> ReviewState {
        switch decision {
        case "APPROVED": return .approved
        case "CHANGES_REQUESTED": return .changesRequested
        default: return .pending
        }
    }

    // MARK: - Mutations

    func resolveReviewThread(threadId: String) async throws {
        let mutation = """
        mutation($threadId: ID!) {
          resolveReviewThread(input: { threadId: $threadId }) {
            thread { id isResolved }
          }
        }
        """
        let body: [String: Any] = [
            "query": mutation,
            "variables": ["threadId": threadId],
        ]

        var request = URLRequest(url: URL(string: "https://api.github.com/graphql")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("pr-daemon", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.apiError(text)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let errors = json?["errors"] as? [[String: Any]] {
            let messages = errors.compactMap { $0["message"] as? String }
            throw GitHubError.graphQLError(messages.joined(separator: ", "))
        }
    }

    // MARK: - GraphQL Query

    static let graphQLQuery = """
    query($query: String!) {
      search(query: $query, type: ISSUE, first: 50) {
        nodes {
          ... on PullRequest {
            id
            number
            title
            url
            isDraft
            state
            createdAt
            updatedAt
            repository { nameWithOwner url }
            headRefName
            baseRefName
            reviewDecision
            reviews(last: 10) {
              nodes { author { login } state submittedAt body }
            }
            reviewThreads(last: 30) {
              nodes {
                id
                isResolved
                path
                line
                comments(last: 5) {
                  nodes {
                    id
                    author { login }
                    body
                    createdAt
                    url
                  }
                }
              }
            }
            comments(last: 5) {
              totalCount
              nodes { id author { login } body createdAt url }
            }
            commits(last: 1) {
              nodes {
                commit {
                  statusCheckRollup {
                    state
                    contexts(first: 30) {
                      nodes {
                        ... on CheckRun {
                          __typename name status conclusion completedAt detailsUrl
                        }
                        ... on StatusContext {
                          __typename context state targetUrl
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    """
}

enum GitHubError: LocalizedError {
    case apiError(String)
    case graphQLError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): "GitHub API error: \(msg)"
        case .graphQLError(let msg): "GraphQL error: \(msg)"
        case .parseError: "Failed to parse GitHub response"
        }
    }
}
