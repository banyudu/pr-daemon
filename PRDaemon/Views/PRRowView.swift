import SwiftUI

struct PRRowView: View {
    let pr: PullRequest

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.repo)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Text("#\(pr.number) \(pr.title)")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(pr.branch)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if pr.isDraft {
                        Text("Draft")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    if pr.commentCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 9))
                            Text("\(pr.commentCount)")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(pr.updatedAt, style: .relative)
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }

            VStack(alignment: .trailing, spacing: 3) {
                StatusBadge(status: pr.overallCheckStatus)
                ReviewBadge(state: pr.overallReviewState)
            }
            .padding(.top, 2)
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
