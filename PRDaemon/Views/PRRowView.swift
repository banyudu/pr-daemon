import SwiftUI

extension Date {
    var shortRelative: String {
        let seconds = -self.timeIntervalSinceNow
        if seconds < 60 {
            return "now"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return mins < 10 ? String(format: "%.1fm", mins) : "\(Int(mins))m"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return hours < 10 ? String(format: "%.1fh", hours) : "\(Int(hours))h"
        } else {
            let days = seconds / 86400
            return days < 10 ? String(format: "%.1fd", days) : "\(Int(days))d"
        }
    }
}

struct PRRowView: View {
    let pr: PullRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(pr.repo)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(verbatim: "#\(pr.number)")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue.opacity(0.7))
                            .onTapGesture {
                                if let url = URL(string: pr.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                    }

                    Text(pr.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    StatusBadge(status: pr.filteredCheckStatus)
                    ReviewBadge(state: pr.filteredReviewState)
                }
                .padding(.top, 2)
            }

            HStack(spacing: 6) {
                Text(pr.branch)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.blue.opacity(0.7))
                    .lineLimit(1)
                    .onTapGesture {
                        if let url = URL(string: "\(pr.repoURL)/tree/\(pr.branch)") {
                            NSWorkspace.shared.open(url)
                        }
                    }

                if pr.isDraft {
                    Text("Draft")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                Spacer()

                if pr.filteredCommentCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 9))
                        Text("\(pr.filteredCommentCount)")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }

                if pr.unresolvedAIThreadCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 9))
                        Text("\(pr.unresolvedAIThreadCount)")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.orange)
                }

                if let confidence = pr.greptileConfidence {
                    let filled = Int(round(confidence * 5))
                    let stars = String(repeating: "★", count: filled) + String(repeating: "☆", count: 5 - filled)
                    Text(stars)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }

                Text(pr.updatedAt.shortRelative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Badges

struct StatusBadge: View {
    let status: CheckStatus

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(status.label)
                .font(.system(size: 10))
                .foregroundStyle(textColor)
        }
    }

    private var dotColor: Color {
        switch status {
        case .success: .green
        case .failure: .red
        case .running: .yellow
        case .pending: .gray
        case .neutral: .gray.opacity(0.5)
        }
    }

    private var textColor: Color {
        switch status {
        case .success: .green
        case .failure: .red
        case .running: .orange
        case .pending, .neutral: .secondary
        }
    }
}

struct ReviewBadge: View {
    let state: ReviewState

    var body: some View {
        Text(state.label)
            .font(.system(size: 10))
            .foregroundStyle(textColor)
    }

    private var textColor: Color {
        switch state {
        case .approved: .green
        case .changesRequested: .orange
        case .commented: .blue
        case .pending, .dismissed: .secondary
        }
    }
}

struct StatusDot: View {
    let status: CheckStatus

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 6, height: 6)
    }

    private var dotColor: Color {
        switch status {
        case .success: .green
        case .failure: .red
        case .running: .yellow
        case .pending: .gray
        case .neutral: .gray.opacity(0.5)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
