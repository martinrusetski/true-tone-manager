import Foundation
import os.log

class TrueToneManager {
    static let shared = TrueToneManager()

    private let applicationMonitor: ApplicationMonitor
    private var trueToneController: TrueToneController?
    var preferenceStore: PreferenceStore
    private let log = OSLog(subsystem: "com.truetonemanager", category: "TrueToneManager")

    private static let defaultStateKey = "DefaultTrueToneState"

    private(set) var currentApplication: (bundleIdentifier: String, displayName: String)? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.onStateChanged?()
            }
        }
    }
    var currentTrueToneState: Bool = false {
        didSet {
            if hasLoadedInitialState && oldValue != currentTrueToneState {
                NotificationManager.shared.notifyTrueToneChanged(enabled: currentTrueToneState)
            }
            DispatchQueue.main.async { [weak self] in
                self?.onStateChanged?()
            }
        }
    }

    /// Guards state-change notifications so the first read at launch (which sets
    /// the state up from its `false` seed) doesn't fire a spurious notification.
    private var hasLoadedInitialState = false

    /// Baseline True Tone state applied to any app without an explicit rule.
    /// Captured from the live system state on first launch (we don't assume a
    /// hardcoded default), changeable from the menu, and persisted.
    var defaultTrueToneState: Bool = (UserDefaults.standard.object(forKey: TrueToneManager.defaultStateKey) as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(defaultTrueToneState, forKey: TrueToneManager.defaultStateKey)
        }
    }

    /// True Tone can be controlled right now (a capable display is active).
    var isTrueToneAvailable: Bool {
        return trueToneController?.isAvailable() ?? false
    }

    var onStateChanged: (() -> Void)?

    private init() {
        applicationMonitor = ApplicationMonitor()
        trueToneController = TrueToneController()
        preferenceStore = PreferenceStore()
    }

    init(controller: TrueToneController?, store: PreferenceStore, monitor: ApplicationMonitor) {
        self.trueToneController = controller
        self.preferenceStore = store
        self.applicationMonitor = monitor
    }

    func startAsync(completion: @escaping (Error?) -> Void) {
        do {
            try preferenceStore.loadPreferences()
        } catch {
            os_log(.error, log: log, "Failed to load preferences: %{public}@", error.localizedDescription)
        }

        // Read the real state *before* the monitor fires its initial app-change,
        // so the first rule is evaluated against the actual TrueTone state
        // rather than a stale default.
        if let controller = trueToneController {
            do {
                let state = try controller.getCurrentState()
                currentTrueToneState = state
                captureDefaultIfNeeded(state)
                os_log(.info, log: log, "TrueTone initial state: %{public}@", state ? "On" : "Off")
            } catch {
                os_log(.error, log: log, "Failed to get initial state: %{public}@", error.localizedDescription)
            }
        }
        hasLoadedInitialState = true

        applicationMonitor.delegate = self
        applicationMonitor.start()

        if trueToneController == nil {
            os_log(.error, log: log, "TrueTone controller not available")
            completion(TrueToneControllerError.unsupportedHardware)
        } else {
            completion(nil)
        }
    }

    /// Capture the live system state as the baseline the very first time we run,
    /// so we never assume a hardcoded default.
    private func captureDefaultIfNeeded(_ currentState: Bool) {
        if UserDefaults.standard.object(forKey: Self.defaultStateKey) == nil {
            defaultTrueToneState = currentState
            os_log(.info, log: log, "Captured baseline TrueTone default: %{public}@", currentState ? "On" : "Off")
        }
    }

    /// Re-evaluate after a display configuration change (lid open/close, display
    /// plugged/unplugged). Refreshes the known state and re-applies the current
    /// app's rule now that availability may have changed.
    func handleDisplayConfigurationChange() {
        if let controller = trueToneController, controller.isAvailable(),
           let state = try? controller.getCurrentState() {
            currentTrueToneState = state
            if let current = currentApplication {
                handleApplicationChange(bundleIdentifier: current.bundleIdentifier)
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.onStateChanged?()
        }
    }

    /// Set the baseline default and immediately re-apply the current app's rule
    /// (so changing the default takes effect for apps without an explicit rule).
    func setDefaultTrueTone(enabled: Bool) {
        defaultTrueToneState = enabled
        os_log(.info, log: log, "Default TrueTone set to %{public}@", enabled ? "On" : "Off")
        if let current = currentApplication {
            handleApplicationChange(bundleIdentifier: current.bundleIdentifier)
        }
    }

    func start() throws {
        try preferenceStore.loadPreferences()

        if let controller = trueToneController {
            let state = try controller.getCurrentState()
            currentTrueToneState = state
            os_log(.info, log: log, "TrueTone initial state: %{public}@", state ? "On" : "Off")
        } else {
            os_log(.error, log: log, "TrueTone controller not available - unsupported hardware")
        }
        hasLoadedInitialState = true

        applicationMonitor.delegate = self
        applicationMonitor.start()
    }

    func stop() {
        applicationMonitor.stop()

        do {
            try preferenceStore.savePreferences()
        } catch {
            os_log(.error, log: log, "Failed to save preferences on quit: %{public}@", error.localizedDescription)
        }
    }

    func handleApplicationChange(bundleIdentifier: String) {
        os_log(.info, log: log, "Application changed: %{public}@", bundleIdentifier)

        let targetState: Bool
        if let preference = preferenceStore.getPreference(for: bundleIdentifier) {
            targetState = preference.trueToneEnabled
        } else {
            targetState = defaultTrueToneState
        }

        guard isTrueToneAvailable else {
            os_log(.info, log: log, "TrueTone unavailable, skipping change for %{public}@", bundleIdentifier)
            return
        }

        if targetState == currentTrueToneState {
            os_log(.debug, log: log, "State already matches, no change needed")
            return
        }

        os_log(.info, log: log, "Switching TrueTone to %{public}@ for %{public}@",
               targetState ? "On" : "Off",
               bundleIdentifier)

        do {
            try applyTrueToneState(targetState, for: bundleIdentifier)
            os_log(.info, log: log, "Successfully applied TrueTone %{public}@ for %{public}@",
                   targetState ? "On" : "Off",
                   bundleIdentifier)
        } catch {
            os_log(.error, log: log, "Failed to apply TrueTone state: %{public}@, retrying...",
                   error.localizedDescription)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                do {
                    try self?.applyTrueToneState(targetState, for: bundleIdentifier)
                    os_log(.info, log: self?.log ?? .default,
                           "Retry succeeded for %{public}@", bundleIdentifier)
                } catch {
                    os_log(.error, log: self?.log ?? .default,
                           "Retry failed for %{public}@: %{public}@",
                           bundleIdentifier,
                           error.localizedDescription)
                }
            }
        }
    }

    private func applyTrueToneState(_ enabled: Bool, for bundleIdentifier: String) throws {
        guard let controller = trueToneController else {
            throw TrueToneControllerError.unsupportedHardware
        }

        try controller.setTrueTone(enabled: enabled)
        currentTrueToneState = enabled
    }

    /// Apply the state if TrueTone is controllable right now; otherwise leave it
    /// for the next display-configuration change. The preference is already
    /// persisted, so the intent isn't lost.
    private func applyIfAvailable(_ enabled: Bool, for bundleIdentifier: String) {
        guard isTrueToneAvailable else {
            os_log(.info, log: log, "TrueTone unavailable, preference saved but not applied for %{public}@", bundleIdentifier)
            return
        }
        do {
            try applyTrueToneState(enabled, for: bundleIdentifier)
        } catch {
            os_log(.error, log: log, "Failed to apply TrueTone state for %{public}@: %{public}@",
                   bundleIdentifier, error.localizedDescription)
        }
    }

    func setPreferenceForCurrentApp(enabled: Bool) throws {
        guard let current = currentApplication else {
            throw ApplicationMonitorError.bundleIdentifierUnavailable
        }

        try setPreference(
            bundleIdentifier: current.bundleIdentifier,
            displayName: current.displayName,
            enabled: enabled
        )
    }

    func removePreferenceForCurrentApp() throws {
        guard let current = currentApplication else {
            throw ApplicationMonitorError.bundleIdentifierUnavailable
        }

        try removePreference(bundleIdentifier: current.bundleIdentifier)
    }

    /// Set (or replace) the rule for an arbitrary bundle identifier, e.g. from the
    /// Settings window's Apps pane. If it's the frontmost app, applies immediately.
    func setPreference(bundleIdentifier: String, displayName: String, enabled: Bool) throws {
        let preference = AppPreference(
            bundleIdentifier: bundleIdentifier,
            trueToneEnabled: enabled,
            displayName: displayName
        )

        try preferenceStore.setPreference(preference)

        if bundleIdentifier == currentApplication?.bundleIdentifier {
            applyIfAvailable(enabled, for: bundleIdentifier)
        }

        os_log(.info, log: log, "Set preference for %{public}@: TrueTone %{public}@",
               bundleIdentifier,
               enabled ? "On" : "Off")
    }

    /// Remove the rule for an arbitrary bundle identifier, e.g. from the Settings
    /// window's Apps pane. If it's the frontmost app, re-applies the default.
    func removePreference(bundleIdentifier: String) throws {
        try preferenceStore.removePreference(for: bundleIdentifier)

        if bundleIdentifier == currentApplication?.bundleIdentifier {
            applyIfAvailable(defaultTrueToneState, for: bundleIdentifier)
        }

        os_log(.info, log: log, "Removed preference for %{public}@, restored default TrueTone %{public}@",
               bundleIdentifier, defaultTrueToneState ? "On" : "Off")
    }
}

extension TrueToneManager: ApplicationMonitorDelegate {
    func applicationDidChange(bundleIdentifier: String, displayName: String) {
        currentApplication = (bundleIdentifier, displayName)
        handleApplicationChange(bundleIdentifier: bundleIdentifier)
    }

    func applicationMonitoringFailed(error: ApplicationMonitorError) {
        os_log(.error, log: log, "Application monitoring failed: %{public}@", String(describing: error))
    }
}
