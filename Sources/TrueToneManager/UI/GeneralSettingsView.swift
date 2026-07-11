import SwiftUI

struct GeneralSettingsView: View {
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled()
    @State private var launchAtLoginError: String?
    @State private var defaultTrueToneOn = TrueToneManager.shared.defaultTrueToneState
    @State private var isTrueToneAvailable = TrueToneManager.shared.isTrueToneAvailable
    @State private var updatesAvailable = UpdaterManager.shared.isAvailable
    @State private var autoCheckUpdates = UpdaterManager.shared.automaticallyChecksForUpdates
    @State private var notifyOnChange = NotificationManager.shared.stateChangeNotificationsEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
                if let message = launchAtLoginError {
                    Text(message)
                        .font(.callout)
                        .foregroundColor(.red)
                }
            }

            Section {
                Toggle("True Tone by default", isOn: $defaultTrueToneOn)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: defaultTrueToneOn) { newValue in
                        TrueToneManager.shared.setDefaultTrueTone(enabled: newValue)
                    }
            } footer: {
                Text("Applied to apps without a specific rule.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Notify when True Tone changes", isOn: $notifyOnChange)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: notifyOnChange) { newValue in
                        NotificationManager.shared.stateChangeNotificationsEnabled = newValue
                    }
            } footer: {
                Text("Shows a notification each time True Tone turns on or off.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section {
                LabeledContent("True Tone") {
                    Text(isTrueToneAvailable ? "Available" : "No capable display")
                        .foregroundColor(.secondary)
                }
            }

            if updatesAvailable {
                Section {
                    Toggle("Automatically check for updates", isOn: $autoCheckUpdates)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: autoCheckUpdates) { newValue in
                            UpdaterManager.shared.automaticallyChecksForUpdates = newValue
                        }
                    Button("Check for Updates…") {
                        UpdaterManager.shared.checkForUpdates()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.isEnabled()
            defaultTrueToneOn = TrueToneManager.shared.defaultTrueToneState
            isTrueToneAvailable = TrueToneManager.shared.isTrueToneAvailable
            updatesAvailable = UpdaterManager.shared.isAvailable
            autoCheckUpdates = UpdaterManager.shared.automaticallyChecksForUpdates
            notifyOnChange = NotificationManager.shared.stateChangeNotificationsEnabled
        }
        .onReceive(NotificationCenter.default.publisher(for: UpdaterManager.didChangeSettings)) { _ in
            autoCheckUpdates = UpdaterManager.shared.automaticallyChecksForUpdates
        }
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        // The toggle also fires when we revert it after a failure; skip the
        // system call when the state already matches.
        guard enable != LaunchAtLoginManager.isEnabled() else { return }

        do {
            if enable {
                try LaunchAtLoginManager.enable()
            } else {
                try LaunchAtLoginManager.disable()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLogin = LaunchAtLoginManager.isEnabled()
            launchAtLoginError = error.localizedDescription
        }
    }
}
