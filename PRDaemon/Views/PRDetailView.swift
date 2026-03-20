import SwiftUI

struct PRDetailView: View {
    let pr: PullRequest
    let onBack: () -> Void
    @State private var yoloRunning = false
    @State private var settings = AppSettings.load()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)

                Text(pr.repo)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer()

                Button("Open in GitHub") {
                    if let url = URL(string: pr.url) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleSection
                    statusSection
                    if !pr.filteredChecks.isEmpty { checksSection }
                    if !pr.filteredReviews.isEmpty { reviewsSection }
                    if !pr.filteredComments.isEmpty { commentsSection }
                    quickActionsSection
                }
                .padding(12)
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("#\(pr.number) \(pr.title)")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 4) {
                Text(pr.branch)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)

                Text(pr.baseBranch)
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if pr.isDraft {
                    Text("Draft")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
    }

    private var statusSection: some View {
        HStack(spacing: 12) {
            StatusBadge(status: pr.filteredCheckStatus)
            Divider().frame(height: 14)
            ReviewBadge(state: pr.filteredReviewState)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
    }

    private var checksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Checks")
            VStack(spacing: 0) {
                ForEach(pr.filteredChecks) { check in
                    HStack {
                        Text(check.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        StatusBadge(status: check.status)
                        Button {
                            ignoreReviewer(check.name)
                        } label: {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.borderless)
                        .help("Ignore \(check.name)")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                    if check.id != pr.filteredChecks.last?.id {
                        Divider().padding(.leading, 8)
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Reviews")
            VStack(spacing: 0) {
                ForEach(pr.filteredReviews) { review in
                    HStack {
                        Text("@\(review.author)")
                            .font(.system(size: 12))
                        Spacer()
                        ReviewBadge(state: review.state)
                        Button {
                            ignoreReviewer(review.author)
                        } label: {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.borderless)
                        .help("Ignore @\(review.author)")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                    if review.id != pr.filteredReviews.last?.id {
                        Divider().padding(.leading, 8)
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Recent Comments (\(pr.filteredCommentCount))")
            ForEach(pr.filteredComments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("@\(comment.author)")
                            .font(.system(size: 11, weight: .semibold))
                        Button {
                            ignoreReviewer(comment.author)
                        } label: {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.borderless)
                        .help("Ignore @\(comment.author)")
                        Spacer()
                        Text(comment.createdAt, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Text(comment.body)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding(8)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            }
        }
    }

    private var quickActionsSection: some View {
        HStack(spacing: 8) {
            Button(action: openTerminal) {
                Text("Fix in Terminal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.regular)

            Button(action: runYolo) {
                if yoloRunning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Fix (YOLO)")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.regular)
            .disabled(yoloRunning)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func ignoreReviewer(_ name: String) {
        settings.ignoredReviewers.insert(name)
        settings.save()
    }

    private func openTerminal() {
        let settings = AppSettings.load()
        let repoPath = settings.localRepoPaths[pr.repo] ?? ""
        let context = buildContext()
        QuickActionService.openTerminalWithClaude(repoPath: repoPath, context: context)
    }

    private func runYolo() {
        yoloRunning = true
        let settings = AppSettings.load()
        let repoPath = settings.localRepoPaths[pr.repo] ?? ""
        let prompt = buildContext()
        Task {
            _ = await QuickActionService.runClaudeYolo(repoPath: repoPath, prompt: prompt)
            yoloRunning = false
        }
    }

    private func buildContext() -> String {
        var parts: [String] = []
        if pr.filteredCheckStatus == .failure {
            let failing = pr.filteredChecks.filter { $0.status == .failure }.map(\.name)
            parts.append("Failing checks: \(failing.joined(separator: ", "))")
        }
        if let last = pr.filteredComments.last {
            parts.append("Latest comment from @\(last.author): \(String(last.body.prefix(200)))")
        }
        return parts.isEmpty ? "Fix issues in PR #\(pr.number): \(pr.title)" : parts.joined(separator: "\n")
    }
}
