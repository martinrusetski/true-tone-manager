import AppKit
import os.log
import Sparkle

/// Wraps Sparkle's `SPUUpdater`. Owns the auto-update setting, drives the
/// "Check for Updates…" action, and shows a one-time first-launch prompt.
///
/// The updater only becomes functional once a valid `SUFeedURL` and
/// `SUPublicEDKey` are present in Info.plist (see the release pipeline). Until
/// then `start()` throws, `isAvailable` stays false, and the UI disables the
/// update controls instead of crashing.
final class UpdaterManager: NSObject {
    static let shared = UpdaterManager()

    /// Posted after `automaticallyChecksForUpdates` changes so open Settings
    /// windows can refresh their toggle.
    static let didChangeSettings = Notification.Name("com.truetonemanager.updaterSettingsDidChange")

    private let log = OSLog(subsystem: "com.truetonemanager", category: "Updater")
    private let hasPromptedKey = "com.truetonemanager.hasPromptedForAutoUpdates"

    private var updater: SPUUpdater!
    private var userDriver: SPUStandardUserDriver!
    private var started = false

    private override init() {
        super.init()
        let bundle = Bundle.main
        userDriver = SPUStandardUserDriver(hostBundle: bundle, delegate: nil)
        updater = SPUUpdater(
            hostBundle: bundle,
            applicationBundle: bundle,
            userDriver: userDriver,
            delegate: self
        )
    }

    /// Starts the updater (if it can) and, on first launch, asks the user
    /// whether to check for updates automatically.
    func start() {
        do {
            try updater.start()
            started = true
            os_log(.info, log: log, "Sparkle updater started")
        } catch {
            started = false
            os_log(.error, log: log,
                   "Sparkle updater unavailable: %{public}@", error.localizedDescription)
        }

        promptForAutomaticUpdatesIfNeeded()
    }

    /// True when a feed and key are configured and the updater is running.
    var isAvailable: Bool { started }

    /// Mirrors Sparkle's persisted `SUEnableAutomaticChecks` setting.
    var automaticallyChecksForUpdates: Bool {
        get { started ? updater.automaticallyChecksForUpdates : false }
        set {
            guard started else { return }
            updater.automaticallyChecksForUpdates = newValue
            NotificationCenter.default.post(name: Self.didChangeSettings, object: nil)
        }
    }

    /// User-initiated check. Shows Sparkle's progress/UI, including a
    /// "you're up to date" panel when there's nothing new.
    func checkForUpdates() {
        guard started else { return }
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates()
    }

    private func promptForAutomaticUpdatesIfNeeded() {
        let defaults = UserDefaults.standard
        guard started, !defaults.bool(forKey: hasPromptedKey) else { return }

        // Let the menu bar and app finish coming up before interrupting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.started else { return }

            let alert = NSAlert()
            alert.messageText = "Check for updates automatically?"
            alert.informativeText = """
            TrueTone Manager can check for new versions and let you install them \
            with one click. You can change this any time in Settings.
            """
            alert.addButton(withTitle: "Check Automatically")
            alert.addButton(withTitle: "Don't Check")

            NSApp.activate(ignoringOtherApps: true)
            let enabled = alert.runModal() == .alertFirstButtonReturn

            self.updater.automaticallyChecksForUpdates = enabled
            defaults.set(true, forKey: self.hasPromptedKey)
            NotificationCenter.default.post(name: Self.didChangeSettings, object: nil)

            if enabled {
                self.updater.checkForUpdatesInBackground()
            }
        }
    }
}

extension UpdaterManager: SPUUpdaterDelegate {
    /// We run our own first-launch prompt, so suppress Sparkle's built-in one.
    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool {
        return false
    }
}
