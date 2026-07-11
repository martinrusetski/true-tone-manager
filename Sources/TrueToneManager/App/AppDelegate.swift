import AppKit
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = OSLog(subsystem: "com.truetonemanager", category: "AppDelegate")
    private var menuBarInterface: MenuBarInterface!

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log(.info, log: log, "App launching")

        if #available(macOS 13.0, *), LaunchAtLoginManager.isDesiredEnabled() {
            try? LaunchAtLoginManager.enable()
        }

        let manager = TrueToneManager.shared

        menuBarInterface = MenuBarInterface(manager: manager)
        menuBarInterface.setup()

        manager.onStateChanged = { [weak self] in
            self?.menuBarInterface?.updateMenu()
        }

        // Starts Sparkle and, on first launch, asks about automatic updates.
        UpdaterManager.shared.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        manager.startAsync { error in
            if let error = error {
                os_log(.error, log: self.log, "Failed to start: %{public}@", error.localizedDescription)
            } else {
                os_log(.info, log: self.log, "TrueTone Manager started")
            }
        }
    }

    @objc private func handleScreenParametersChanged() {
        os_log(.info, log: log, "Display configuration changed")
        TrueToneManager.shared.handleDisplayConfigurationChange()
    }

    func applicationWillTerminate(_ notification: Notification) {
        do {
            try TrueToneManager.shared.preferenceStore.savePreferences()
            os_log(.info, log: log, "Preferences saved on quit")
        } catch {
            os_log(.error, log: log, "Failed to save preferences on quit: %{public}@", error.localizedDescription)
            NotificationManager.shared.showError(
                type: "save_preferences",
                title: "Failed to Save Preferences",
                message: "Your preferences could not be saved. They may be lost when the application quits."
            )
        }

        TrueToneManager.shared.stop()
        menuBarInterface.teardown()
    }
}
