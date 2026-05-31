import Foundation
import os.log

class TrueToneManager {
    static let shared = TrueToneManager()

    private let applicationMonitor: ApplicationMonitor
    private var trueToneController: TrueToneController?
    var preferenceStore: PreferenceStore
    private let log = OSLog(subsystem: "com.truetonemanager", category: "TrueToneManager")

    private(set) var currentApplication: (bundleIdentifier: String, displayName: String)? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.onStateChanged?()
            }
        }
    }
    var currentTrueToneState: Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.onStateChanged?()
            }
        }
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

        applicationMonitor.delegate = self
        applicationMonitor.start()

        guard let controller = trueToneController else {
            os_log(.error, log: log, "TrueTone controller not available")
            completion(TrueToneControllerError.unsupportedHardware)
            return
        }

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            do {
                let state = try controller.getCurrentState()
                DispatchQueue.main.async {
                    self.currentTrueToneState = state
                    os_log(.info, log: self.log, "TrueTone initial state: %{public}@", state ? "On" : "Off")
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    os_log(.error, log: self.log, "Failed to get state: %{public}@", error.localizedDescription)
                    completion(error)
                }
            }
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
            targetState = true
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

    func setPreferenceForCurrentApp(enabled: Bool) throws {
        guard let current = currentApplication else {
            throw ApplicationMonitorError.bundleIdentifierUnavailable
        }

        let preference = AppPreference(
            bundleIdentifier: current.bundleIdentifier,
            trueToneEnabled: enabled,
            displayName: current.displayName
        )

        try preferenceStore.setPreference(preference)
        try applyTrueToneState(enabled, for: current.bundleIdentifier)

        os_log(.info, log: log, "Set preference for %{public}@: TrueTone %{public}@",
               current.bundleIdentifier,
               enabled ? "On" : "Off")
    }

    func removePreferenceForCurrentApp() throws {
        guard let current = currentApplication else {
            throw ApplicationMonitorError.bundleIdentifierUnavailable
        }

        try preferenceStore.removePreference(for: current.bundleIdentifier)
        try applyTrueToneState(true, for: current.bundleIdentifier)

        os_log(.info, log: log, "Removed preference for %{public}@, TrueTone re-enabled", current.bundleIdentifier)
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
