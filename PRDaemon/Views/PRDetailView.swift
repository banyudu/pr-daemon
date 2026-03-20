import SwiftUI

struct PRDetailView: View {
    let pr: PullRequest
    let onBack: () -> Void
    @State private var yoloRunning = false
    @State private var resolvingThreads: Set<String> = []
    @State private var fixingThreads: Set<String> = []
    @State private var settings = AppSettings.load()
    @EnvironmentObject var authService: AuthService

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
                    if !pr.reviewThreads.isEmpty { aiReviewsSection }
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

    private var aiReviewsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let unresolved = pr.unresolvedThreads
            let resolved = pr.reviewThreads.filter { thread in
                thread.isResolved && thread.comments.contains { AIReviewer.isAIReviewer($0.author) }
            }
            sectionHeader("AI Reviews (\(unresolved.count) unresolved)")

            ForEach(unresolved) { thread in
                aiThreadCard(thread: thread, dimmed: false)
            }

            if !resolved.isEmpty {
                DisclosureGroup {
                    ForEach(resolved) { thread in
                        aiThreadCard(thread: thread, dimmed: true)
                    }
                } label: {
                    Text("\(resolved.count) resolved")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func aiThreadCard(thread: ReviewThread, dimmed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // File path + line
            if let path = thread.path {
                HStack(spacing: 2) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                    Text(thread.line.map { "\(path):\($0)" } ?? path)
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }

            // Comment body
            if let comment = thread.comments.first {
                let metadata = AIReviewParser.parseMetadata(author: comment.author, body: comment.body)

                HStack {
                    Text("@\(comment.author)")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    // Metadata pills
                    if let severity = metadata?.severity {
                        Text(severity)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(severityColor(severity).opacity(0.15))
                            .foregroundStyle(severityColor(severity))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    if let confidence = metadata?.confidence {
                        Text("\(Int(confidence * 100))%")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                Text(Self.stripHTML(comment.body))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Action buttons
            if !dimmed {
                HStack(spacing: 8) {
                    Button {
                        fixThread(thread)
                    } label: {
                        if fixingThreads.contains(thread.id) {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Fix", systemImage: "wand.and.stars")
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .foregroundStyle(.purple)
                    .disabled(fixingThreads.contains(thread.id))

                    Button {
                        resolveThread(thread)
                    } label: {
                        if resolvingThreads.contains(thread.id) {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Resolve", systemImage: "checkmark.circle")
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                    .disabled(resolvingThreads.contains(thread.id))
                }
            }
        }
        .padding(8)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        .opacity(dimmed ? 0.5 : 1)
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "critical": .red
        case "warning": .orange
        case "suggestion": .blue
        case "nitpick": .gray
        default: .secondary
        }
    }

    private func fixThread(_ thread: ReviewThread) {
        fixingThreads.insert(thread.id)
        let settings = AppSettings.load()
        let repoPath = settings.localRepoPaths[pr.repo] ?? ""
        var parts: [String] = ["Fix AI review comment on PR #\(pr.number): \(pr.title)"]
        if let path = thread.path {
            var loc = "File: \(path)"
            if let line = thread.line { loc += ":\(line)" }
            parts.append(loc)
        }
        if let comment = thread.comments.first {
            parts.append("Review comment from @\(comment.author):\n\(String(comment.body.prefix(500)))")
        }
        let prompt = parts.joined(separator: "\n")
        Task {
            _ = await QuickActionService.runClaudeYolo(repoPath: repoPath, prompt: prompt)
            fixingThreads.remove(thread.id)
        }
    }

    private func resolveThread(_ thread: ReviewThread) {
        guard let token = authService.token else { return }
        resolvingThreads.insert(thread.id)
        Task {
            let client = GitHubClient(token: token)
            try? await client.resolveReviewThread(threadId: thread.id)
            resolvingThreads.remove(thread.id)
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
                    Text(Self.stripHTML(comment.body))
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

    nonisolated static func stripHTML(_ string: String) -> String {
        string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
