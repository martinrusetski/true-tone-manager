import AppKit
import SwiftUI
import UniformTypeIdentifiers
import os.log

/// Reloads the rule list from the store whenever preferences change,
/// so edits made from the menu bar show up here immediately.
class AppRulesViewModel: ObservableObject {
    @Published var preferences: [AppPreference] = []

    private let log = OSLog(subsystem: "com.truetonemanager", category: "AppRulesViewModel")
    private var observer: NSObjectProtocol?

    init() {
        reload()
        observer = NotificationCenter.default.addObserver(
            forName: .preferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func reload() {
        preferences = TrueToneManager.shared.preferenceStore.getAllPreferences()
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    func setRule(bundleIdentifier: String, displayName: String, enabled: Bool) {
        do {
            try TrueToneManager.shared.setPreference(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName,
                enabled: enabled
            )
        } catch {
            os_log(.error, log: log, "Failed to set rule for %{public}@: %{public}@",
                   bundleIdentifier, error.localizedDescription)
            presentError("Could Not Save Rule", error.localizedDescription)
        }
    }

    func removeRule(bundleIdentifier: String) {
        do {
            try TrueToneManager.shared.removePreference(bundleIdentifier: bundleIdentifier)
        } catch {
            os_log(.error, log: log, "Failed to remove rule for %{public}@: %{public}@",
                   bundleIdentifier, error.localizedDescription)
            presentError("Could Not Remove Rule", error.localizedDescription)
        }
    }

    func addRuleFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else {
            presentError(
                "Can't Add This App",
                "This app has no bundle identifier, so it can't be added here. "
                    + "To set a rule for it, use the menu bar icon while the app is frontmost."
            )
            return
        }

        let displayName = FileManager.default.displayName(atPath: url.path)
        setRule(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            enabled: TrueToneManager.shared.defaultTrueToneState
        )
    }

    func icon(for bundleIdentifier: String) -> NSImage {
        if !bundleIdentifier.hasPrefix("wine:"),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    private func presentError(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

struct AppRulesSettingsView: View {
    @StateObject private var viewModel = AppRulesViewModel()
    @State private var selectedBundleIdentifier: String?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.preferences.isEmpty {
                emptyState
            } else {
                ruleList
            }

            Divider()
            buttonBar
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No app rules yet. Click + to add one,\nor use the menu bar icon while an app is active.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var ruleList: some View {
        List(selection: $selectedBundleIdentifier) {
            ForEach(viewModel.preferences, id: \.bundleIdentifier) { preference in
                AppRuleRow(preference: preference, viewModel: viewModel)
                    .tag(preference.bundleIdentifier)
            }
        }
        .listStyle(.inset)
    }

    private var buttonBar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.addRuleFromOpenPanel()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Add a rule for an application")

            Button {
                if let selected = selectedBundleIdentifier {
                    viewModel.removeRule(bundleIdentifier: selected)
                    selectedBundleIdentifier = nil
                }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(selectedBundleIdentifier == nil)
            .help("Remove the selected rule")

            Spacer()
        }
        .padding(6)
    }
}

private struct AppRuleRow: View {
    let preference: AppPreference
    let viewModel: AppRulesViewModel

    var body: some View {
        HStack {
            Image(nsImage: viewModel.icon(for: preference.bundleIdentifier))
                .resizable()
                .frame(width: 20, height: 20)

            Text(preference.displayName)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Toggle("", isOn: Binding(
                get: { preference.trueToneEnabled },
                set: { newValue in
                    viewModel.setRule(
                        bundleIdentifier: preference.bundleIdentifier,
                        displayName: preference.displayName,
                        enabled: newValue
                    )
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
