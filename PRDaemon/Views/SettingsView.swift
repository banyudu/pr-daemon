import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    @State private var settings = AppSettings.load()
    @State private var installedTerminals = TerminalApp.detectInstalled()
    @EnvironmentObject var pollingService: PollingService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pollIntervalSection
                    notificationsSection
                    agentCommandSection
                    terminalSection
                    worktreeSection
                    ignoredReviewersSection
                    watchedReposSection

                    Divider()

                    // Quit
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Text("Quit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(12)
            }
            .onChange(of: settings) { _, newValue in
                var s = newValue
                if s.pollIntervalMinutes < 0.5 {
                    s.pollIntervalMinutes = 0.5
                }
                s.save()
            }
        }
    }

    // MARK: - Poll Interval

    private var pollIntervalSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Poll Interval")
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    TextField("", value: $settings.pollIntervalMinutes, format: .number)
                        .textFieldStyle(.plain)
                        .frame(width: 36)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 12))

                    VStack(spacing: 0) {
                        Button {
                            settings.pollIntervalMinutes = min(60, settings.pollIntervalMinutes + 0.5)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 6, weight: .bold))
                                .frame(width: 14, height: 8)
                        }
                        .buttonStyle(.borderless)

                        Divider().frame(width: 10)

                        Button {
                            settings.pollIntervalMinutes = max(0.5, settings.pollIntervalMinutes - 0.5)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 6, weight: .bold))
                                .frame(width: 14, height: 8)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary))

                Text("minutes")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Notifications")
            VStack(spacing: 0) {
                notificationToggle("Enable notifications", isOn: $settings.showNotifications, isEnabled: true)
                Divider().padding(.leading, 8)
                notificationToggle("New comments", isOn: $settings.notifyOnNewComments, isEnabled: settings.showNotifications)
                Divider().padding(.leading, 8)
                notificationToggle("Check completes", isOn: $settings.notifyOnCheckComplete, isEnabled: settings.showNotifications)
                Divider().padding(.leading, 8)
                notificationToggle("Review submitted", isOn: $settings.notifyOnReviewSubmitted, isEnabled: settings.showNotifications)
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        }
    }

    // MARK: - Agent Command

    private var agentCommandSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Agent Command")
            VStack(alignment: .leading, spacing: 8) {
                Picker("Command", selection: $settings.agentCommandOption) {
                    ForEach(AgentCommandOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                if settings.agentCommandOption == .custom {
                    TextField("Custom command", text: $settings.claudeCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
            }
        }
    }

    // MARK: - Terminal

    private var availableModes: [TerminalOpenMode] {
        settings.terminalApp.supportedModes
    }

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Terminal")
            VStack(alignment: .leading, spacing: 8) {
                Picker("App", selection: $settings.terminalApp) {
                    ForEach(installedTerminals, id: \.self) { app in
                        Text(app.label).tag(app)
                    }
                }
                .font(.system(size: 12))
                .onChange(of: settings.terminalApp) { _, newApp in
                    if !newApp.supportedModes.contains(settings.terminalOpenMode) {
                        settings.terminalOpenMode = newApp.supportedModes.first ?? .window
                    }
                }

                Picker("Open as", selection: $settings.terminalOpenMode) {
                    ForEach(availableModes, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .font(.system(size: 12))
            }
        }
    }

    // MARK: - Worktree Directory

    private var worktreeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Worktree Directory")
            VStack(alignment: .leading, spacing: 8) {
                Picker("Directory", selection: $settings.worktreeDirectoryOption) {
                    ForEach(WorktreeDirectoryOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .font(.system(size: 12))

                if settings.worktreeDirectoryOption == .custom {
                    TextField("Custom path", text: $settings.customWorktreeDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
            }
        }
    }

    // MARK: - Ignored Reviewers

    @State private var ignoredExpanded = false
    @State private var newIgnoredName = ""

    private var ignoredReviewersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureGroup(isExpanded: $ignoredExpanded) {
                if settings.ignoredReviewers.isEmpty {
                    Text("No ignored reviewers")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(settings.ignoredReviewers.sorted(), id: \.self) { name in
                            HStack {
                                Text(name)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    settings.ignoredReviewers.remove(name)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Stop ignoring \(name)")
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                }

                HStack(spacing: 4) {
                    TextField("Add name...", text: $newIgnoredName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onSubmit { addIgnoredReviewer() }
                    Button {
                        addIgnoredReviewer()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.borderless)
                    .disabled(newIgnoredName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 4)
            } label: {
                Text("IGNORED REVIEWERS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addIgnoredReviewer() {
        let name = newIgnoredName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.ignoredReviewers.insert(name)
        newIgnoredName = ""
    }

    // MARK: - Watched Repos

    @State private var reposExpanded = false

    private var watchedReposSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let repos = allRepoNames
            DisclosureGroup(isExpanded: $reposExpanded) {
                if repos.isEmpty {
                    Text("No repos found yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(repos, id: \.self) { repo in
                            HStack {
                                Text(repo)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { !settings.unwatchedRepos.contains(repo) },
                                    set: { watched in
                                        if watched {
                                            settings.unwatchedRepos.remove(repo)
                                        } else {
                                            settings.unwatchedRepos.insert(repo)
                                        }
                                    }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)

                            if repo != repos.last {
                                Divider().padding(.leading, 8)
                            }
                        }
                    }
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                }
            } label: {
                Text("WATCHED REPOS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var allRepoNames: [String] {
        let fromPolling = pollingService.allRepos
        let fromUnwatched = settings.unwatchedRepos
        return fromPolling.union(fromUnwatched).sorted()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func notificationToggle(_ label: String, isOn: Binding<Bool>, isEnabled: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

}
