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

    @discardableResult
    func removeRule(bundleIdentifier: String) -> Bool {
        do {
            try TrueToneManager.shared.removePreference(bundleIdentifier: bundleIdentifier)
            return true
        } catch {
            os_log(.error, log: log, "Failed to remove rule for %{public}@: %{public}@",
                   bundleIdentifier, error.localizedDescription)
            presentError("Could Not Remove Rule", error.localizedDescription)
            return false
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
        let alert = NSAlert()
        alert.messageText = "Set True Tone Rule"
        alert.informativeText = "Choose what True Tone should do while \(displayName) is active."
        alert.addButton(withTitle: "Always On")
        alert.addButton(withTitle: "Always Off")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        let enabled: Bool
        switch response {
        case .alertFirstButtonReturn:
            enabled = true
        case .alertSecondButtonReturn:
            enabled = false
        default:
            return
        }

        setRule(bundleIdentifier: bundleIdentifier, displayName: displayName, enabled: enabled)
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
    private let ruleColumnWidth: CGFloat = 120

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.preferences.isEmpty {
                emptyState
            } else {
                ruleList
            }

            buttonBar
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Per-app rules")
                .font(.headline)

            Text("These rules override the default while an app is active. Apps without a rule use the default configured in General.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No app-specific rules yet. Click + to add one,\nor use the menu bar icon while an app is active.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var ruleList: some View {
        List(selection: $selectedBundleIdentifier) {
            HStack {
                Spacer()
                Text("True Tone rule")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: ruleColumnWidth, alignment: .trailing)
                    .offset(x: -14)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 1, trailing: 20))
            .listRowSeparator(.hidden)

            ForEach(viewModel.preferences, id: \.bundleIdentifier) { preference in
                AppRuleRow(
                    preference: preference,
                    viewModel: viewModel,
                    ruleColumnWidth: ruleColumnWidth,
                    onRuleRemoved: {
                        if selectedBundleIdentifier == preference.bundleIdentifier {
                            selectedBundleIdentifier = nil
                        }
                    }
                )
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
                    if viewModel.removeRule(bundleIdentifier: selected) {
                        selectedBundleIdentifier = nil
                    }
                }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(selectedBundleIdentifier == nil)
            .help("Remove the selected app rule and use the default")

            Spacer()
        }
        .padding(6)
    }
}

private enum AppRuleSelection: String, CaseIterable, Identifiable {
    case useDefault
    case alwaysOn
    case alwaysOff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .useDefault:
            return "Use Default"
        case .alwaysOn:
            return "Always On"
        case .alwaysOff:
            return "Always Off"
        }
    }
}

private struct AppRuleRow: View {
    let preference: AppPreference
    let viewModel: AppRulesViewModel
    let ruleColumnWidth: CGFloat
    let onRuleRemoved: () -> Void

    var body: some View {
        HStack {
            Image(nsImage: viewModel.icon(for: preference.bundleIdentifier))
                .resizable()
                .frame(width: 20, height: 20)

            Text(preference.displayName)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Picker("True Tone rule", selection: Binding(
                get: {
                    preference.trueToneEnabled ? AppRuleSelection.alwaysOn : AppRuleSelection.alwaysOff
                },
                set: { (selection: AppRuleSelection) in
                    switch selection {
                    case .useDefault:
                        if viewModel.removeRule(bundleIdentifier: preference.bundleIdentifier) {
                            onRuleRemoved()
                        }
                    case .alwaysOn where preference.trueToneEnabled:
                        break
                    case .alwaysOn:
                        viewModel.setRule(
                            bundleIdentifier: preference.bundleIdentifier,
                            displayName: preference.displayName,
                            enabled: true
                        )
                    case .alwaysOff where !preference.trueToneEnabled:
                        break
                    case .alwaysOff:
                        viewModel.setRule(
                            bundleIdentifier: preference.bundleIdentifier,
                            displayName: preference.displayName,
                            enabled: false
                        )
                    }
                }
            )) {
                ForEach(AppRuleSelection.allCases) { selection in
                    Text(selection.title).tag(selection)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .labelsHidden()
            .frame(width: ruleColumnWidth, alignment: .trailing)
            .accessibilityLabel("True Tone rule for \(preference.displayName)")
        }
        .padding(.vertical, 2)
    }
}
