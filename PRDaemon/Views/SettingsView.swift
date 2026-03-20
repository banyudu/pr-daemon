import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
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
                    // Poll interval
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Poll Interval")
                        HStack {
                            TextField("Minutes", value: $settings.pollIntervalMinutes, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("minutes")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Notifications
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("Notifications")
                        VStack(spacing: 0) {
                            settingsToggle("Enable notifications", isOn: $settings.showNotifications)
                            Divider().padding(.leading, 8)
                            settingsToggle("New comments", isOn: $settings.notifyOnNewComments)
                            Divider().padding(.leading, 8)
                            settingsToggle("Check completes", isOn: $settings.notifyOnCheckComplete)
                            Divider().padding(.leading, 8)
                            settingsToggle("Review submitted", isOn: $settings.notifyOnReviewSubmitted)
                        }
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    }

                    // Claude command
                    VStack(alignment: .leading, spacing: 6) {
                        sectionHeader("Commands")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Claude command")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            TextField("claude", text: $settings.claudeCommand)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                    }

                    // Save
                    Button(action: save) {
                        Text("Save Settings")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Divider()

                    // Logout
                    Button(action: {
                        authService.logout()
                        onBack()
                    }) {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.regular)

                    // Quit
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Text("Quit PR Daemon")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(12)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    private func save() {
        settings.save()
    }
}
