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

    func setRule(bundleIdentifier: String, displayName: String, enabled: Bool?) {
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

    func addApplicationFromOpenPanel() {
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

        guard TrueToneManager.shared.preferenceStore.getPreference(for: bundleIdentifier) == nil else {
            return
        }

        let displayName = FileManager.default.displayName(atPath: url.path)
        setRule(bundleIdentifier: bundleIdentifier, displayName: displayName, enabled: nil)
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
    private let ruleColumnWidth: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            header
            ruleTable
            buttonBar
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Per-app rules")
                .font(.headline)
                .accessibilityHeading(.h2)

            Text("These rules override the default while an app is active. Apps without a rule use the default configured in General.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        Text("No apps added yet. Click + to add one,\nor use the menu bar icon while an app is active.")
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }

    private var ruleTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("App")

                Spacer()

                Text("True Tone rule")
                    .frame(width: ruleColumnWidth, alignment: .leading)
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.primary.opacity(0.06))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App rules table columns: App and True Tone rule")

            Divider()

            if viewModel.preferences.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.preferences.enumerated()), id: \.element.id) { index, preference in
                            HStack(spacing: 8) {
                                Button {
                                    selectedBundleIdentifier = preference.id
                                } label: {
                                    AppIdentityCell(preference: preference, viewModel: viewModel)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .foregroundColor(
                                    selectedBundleIdentifier == preference.id ? .white : .primary
                                )

                                AppRulePicker(
                                    preference: preference,
                                    viewModel: viewModel
                                )
                                .frame(width: ruleColumnWidth, alignment: .leading)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(rowColor(index: index, preference: preference))
                            .accessibilityElement(children: .contain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
        .padding(.horizontal, 12)
    }

    private func rowColor(index: Int, preference: AppPreference) -> Color {
        if selectedBundleIdentifier == preference.id {
            return .accentColor
        }
        return alternatingRowColor(index)
    }

    private func alternatingRowColor(_ index: Int) -> Color {
        index.isMultiple(of: 2) ? .clear : Color.primary.opacity(0.06)
    }

    private var buttonBar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.addApplicationFromOpenPanel()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Add an application")

            Button {
                if let selected = selectedBundleIdentifier {
                    if viewModel.removeRule(bundleIdentifier: selected) {
                        selectedBundleIdentifier = nil
                    }
                }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(selectedBundleIdentifier == nil)
            .help("Remove the selected app rule and use the default")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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

private struct AppIdentityCell: View {
    let preference: AppPreference
    let viewModel: AppRulesViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: viewModel.icon(for: preference.bundleIdentifier))
                .resizable()
                .frame(width: 20, height: 20)

            Text(preference.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

private struct AppRulePicker: View {
    let preference: AppPreference
    let viewModel: AppRulesViewModel

    var body: some View {
        Picker("True Tone rule", selection: selection) {
            ForEach(AppRuleSelection.allCases) { selection in
                Text(selection.title).tag(selection)
            }
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("True Tone rule for \(preference.displayName)")
    }

    private var selection: Binding<AppRuleSelection> {
        Binding(
            get: {
                switch preference.trueToneEnabled {
                case true:
                    return .alwaysOn
                case false:
                    return .alwaysOff
                case nil:
                    return .useDefault
                }
            },
            set: { selection in
                switch selection {
                case .useDefault:
                    viewModel.setRule(
                        bundleIdentifier: preference.bundleIdentifier,
                        displayName: preference.displayName,
                        enabled: nil
                    )
                case .alwaysOn where preference.trueToneEnabled == true:
                    break
                case .alwaysOn:
                    viewModel.setRule(
                        bundleIdentifier: preference.bundleIdentifier,
                        displayName: preference.displayName,
                        enabled: true
                    )
                case .alwaysOff where preference.trueToneEnabled == false:
                    break
                case .alwaysOff:
                    viewModel.setRule(
                        bundleIdentifier: preference.bundleIdentifier,
                        displayName: preference.displayName,
                        enabled: false
                    )
                }
            }
        )
    }
}
