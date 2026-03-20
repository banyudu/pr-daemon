import SwiftUI

struct MainView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var pollingService: PollingService
    @State private var searchText = ""
    @State private var filter: PRFilter = .all
    @State private var selectedPR: PullRequest?
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    enum PRFilter: String, CaseIterable {
        case all = "All"
        case open = "Open"
        case draft = "Draft"
        case attention = "Attention"
    }

    var filteredPRs: [PullRequest] {
        var prs = pollingService.pullRequests

        switch filter {
        case .all: break
        case .open: prs = prs.filter { !$0.isDraft }
        case .draft: prs = prs.filter { $0.isDraft }
        case .attention: prs = prs.filter { $0.needsAttention }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            prs = prs.filter {
                $0.title.lowercased().contains(q) ||
                $0.repo.lowercased().contains(q) ||
                "#\($0.number)".contains(q)
            }
        }

        return prs
    }

    var body: some View {
        VStack(spacing: 0) {
            if let pr = selectedPR {
                PRDetailView(pr: pr, onBack: { selectedPR = nil })
            } else if showSettings {
                SettingsView(onBack: { showSettings = false })
            } else {
                headerBar
                searchBar
                prList
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                selectedPR = nil
                showSettings = false
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 4) {
                Text("PRs")
                    .font(.system(size: 13, weight: .semibold))
                if let username = authService.username {
                    Text("@\(username)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let lastFetched = pollingService.lastFetched {
                Text(lastFetched, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Button(action: { Task { await pollingService.fetchPRs() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Refresh")

            Button(action: {
                pollingService.togglePause()
            }) {
                Image(systemName: pollingService.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help(pollingService.isPaused ? "Resume polling" : "Pause polling")

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Quit")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Search

    private var searchBar: some View {
        VStack(spacing: 6) {
            TextField("Search PRs...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            HStack(spacing: 4) {
                ForEach(PRFilter.allCases, id: \.self) { f in
                    Button(f.rawValue) { filter = f }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(filter == f ? .accentColor : .secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - List

    private var prList: some View {
        Group {
            if pollingService.isLoading {
                Spacer()
                ProgressView("Loading PRs...")
                    .font(.system(size: 12))
                Spacer()
            } else if let error = pollingService.error {
                Spacer()
                VStack(spacing: 8) {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await pollingService.fetchPRs() } }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding()
                Spacer()
            } else if filteredPRs.isEmpty {
                Spacer()
                Text(pollingService.pullRequests.isEmpty ? "No open PRs" : "No PRs match filters")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPRs) { pr in
                            PRRowView(pr: pr)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedPR = pr }
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }
}
