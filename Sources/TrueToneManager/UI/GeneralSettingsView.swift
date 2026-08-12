import SwiftUI

struct GeneralSettingsView: View {
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled()
    @State private var launchAtLoginError: String?
    @State private var hideMenuBarIcon = MenuBarIconManager.isHidden
    @State private var defaultTrueToneOn = TrueToneManager.shared.defaultTrueToneState
    @State private var isTrueToneAvailable = TrueToneManager.shared.isTrueToneAvailable
    @State private var updatesAvailable = UpdaterManager.shared.isAvailable
    @State private var autoCheckUpdates = UpdaterManager.shared.automaticallyChecksForUpdates
    @State private var notifyOnChange = NotificationManager.shared.stateChangeNotificationsEnabled

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsGroup {
                    SettingsToggleRow("Launch at login", isOn: $launchAtLogin) {
                        setLaunchAtLogin(launchAtLogin)
                    }
                    if let message = launchAtLoginError {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    SettingsToggleRow(
                        "Hide menu bar icon",
                        detail: "Launch TrueTone Manager to open Settings when the icon is hidden.",
                        isOn: $hideMenuBarIcon
                    ) {
                        MenuBarIconManager.isHidden = hideMenuBarIcon
                    }

                    Divider()

                    SettingsToggleRow(
                        "True Tone by default",
                        detail: "Applied to apps without a specific rule.",
                        isOn: $defaultTrueToneOn
                    ) {
                        TrueToneManager.shared.setDefaultTrueTone(enabled: defaultTrueToneOn)
                    }

                    Divider()

                    SettingsToggleRow(
                        "Notify when True Tone changes",
                        detail: "Shows a notification each time True Tone turns on or off.",
                        isOn: $notifyOnChange
                    ) {
                        NotificationManager.shared.stateChangeNotificationsEnabled = notifyOnChange
                    }
                }

                SettingsGroup {
                    LabeledContent("True Tone") {
                        Text(isTrueToneAvailable ? "Available" : "No capable display")
                            .foregroundColor(.secondary)
                    }
                }

                if updatesAvailable {
                    SettingsGroup {
                        SettingsToggleRow("Automatically check for updates", isOn: $autoCheckUpdates) {
                            UpdaterManager.shared.automaticallyChecksForUpdates = autoCheckUpdates
                        }

                        Divider()

                        Button("Check for Updates…") {
                            UpdaterManager.shared.checkForUpdates()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            launchAtLogin = LaunchAtLoginManager.isEnabled()
            hideMenuBarIcon = MenuBarIconManager.isHidden
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

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool
    let onChange: () -> Void

    init(
        _ title: String,
        detail: String? = nil,
        isOn: Binding<Bool>,
        onChange: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self._isOn = isOn
        self.onChange = onChange
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .onChange(of: isOn) { _ in onChange() }
    }
}
