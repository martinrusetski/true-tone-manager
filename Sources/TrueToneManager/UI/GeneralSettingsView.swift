import SwiftUI

struct GeneralSettingsView: View {
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled()
    @State private var launchAtLoginError: String?
    @State private var defaultTrueToneOn = TrueToneManager.shared.defaultTrueToneState
    @State private var isTrueToneAvailable = TrueToneManager.shared.isTrueToneAvailable

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
                LabeledContent("True Tone") {
                    Text(isTrueToneAvailable ? "Available" : "No capable display")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.isEnabled()
            defaultTrueToneOn = TrueToneManager.shared.defaultTrueToneState
            isTrueToneAvailable = TrueToneManager.shared.isTrueToneAvailable
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
