import Foundation
import UserNotifications

@MainActor
class PollingService: ObservableObject {
    @Published var pullRequests: [PullRequest] = []
    @Published var allRepos: Set<String> = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastFetched: Date?
    @Published var isPaused = false

    private var snapshots: [String: PRSnapshot] = [:]
    private var pollingTask: Task<Void, Never>?
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
        requestNotificationPermission()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchPRs()
                let interval = AppSettings.load().pollIntervalMinutes
                try? await Task.sleep(for: .seconds(interval * 60))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func togglePause() {
        isPaused.toggle()
        if isPaused {
            stopPolling()
        } else {
            startPolling()
        }
    }

    func fetchPRs() async {
        guard let token = authService.token else { return }

        isLoading = pullRequests.isEmpty
        error = nil

        let client = GitHubClient(token: token)
        do {
            let prs = try await client.fetchMyPRs()

            // Track all repos before filtering
            allRepos = Set(prs.map { $0.repo })

            // Filter out unwatched repos
            let settings = AppSettings.load()
            let filtered = prs.filter { !settings.unwatchedRepos.contains($0.repo) }

            // Detect changes and notify
            let changes = detectChanges(newPRs: filtered)
            if !changes.isEmpty {
                sendNotifications(changes: changes)
            }

            // Update snapshots
            snapshots = Dictionary(uniqueKeysWithValues: filtered.map { pr in
                (pr.id, PRSnapshot(
                    checkStatus: pr.overallCheckStatus,
                    reviewState: pr.overallReviewState,
                    commentCount: pr.commentCount
                ))
            })

            pullRequests = filtered
            lastFetched = .now
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func detectChanges(newPRs: [PullRequest]) -> [PRChange] {
        var changes: [PRChange] = []

        for pr in newPRs {
            guard let prev = snapshots[pr.id] else { continue }

            if pr.commentCount > prev.commentCount {
                let count = pr.commentCount - prev.commentCount
                let author = pr.latestComments.last?.author ?? "someone"
                changes.append(PRChange(
                    prNumber: pr.number, prTitle: pr.title, repo: pr.repo,
                    changeType: "comment",
                    message: "\(count) new comment\(count > 1 ? "s" : "") from @\(author)"
                ))
            }

            if pr.overallCheckStatus != prev.checkStatus {
                let msg: String? = switch pr.overallCheckStatus {
                case .success: "All checks passed"
                case .failure: "Checks failed"
                case .running: "Checks started"
                default: nil
                }
                if let msg {
                    changes.append(PRChange(
                        prNumber: pr.number, prTitle: pr.title, repo: pr.repo,
                        changeType: "check", message: msg
                    ))
                }
            }

            if pr.overallReviewState != prev.reviewState {
                let msg: String? = switch pr.overallReviewState {
                case .approved: "PR approved"
                case .changesRequested: "Changes requested"
                default: nil
                }
                if let msg {
                    changes.append(PRChange(
                        prNumber: pr.number, prTitle: pr.title, repo: pr.repo,
                        changeType: "review", message: msg
                    ))
                }
            }
        }

        return changes
    }

    private func sendNotifications(changes: [PRChange]) {
        let settings = AppSettings.load()
        guard settings.showNotifications else { return }

        for change in changes {
            let shouldNotify = switch change.changeType {
            case "comment": settings.notifyOnNewComments
            case "check": settings.notifyOnCheckComplete
            case "review": settings.notifyOnReviewSubmitted
            default: true
            }
            guard shouldNotify else { continue }

            let content = UNMutableNotificationContent()
            content.title = "PR #\(change.prNumber) (\(change.repo))"
            content.body = change.message
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
