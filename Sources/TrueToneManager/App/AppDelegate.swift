import AppKit
import Carbon
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = OSLog(subsystem: "com.truetonemanager", category: "AppDelegate")
    private var menuBarInterface: MenuBarInterface!

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log(.info, log: log, "App launching")
        let launchedAsLoginItem = Self.wasLaunchedAsLoginItem

        if #available(macOS 13.0, *), LaunchAtLoginManager.isDesiredEnabled() {
            try? LaunchAtLoginManager.enable()
        }

        let manager = TrueToneManager.shared

        menuBarInterface = MenuBarInterface(manager: manager)
        menuBarInterface.setup()

        manager.onStateChanged = { [weak self] in
            self?.menuBarInterface?.updateMenu()
        }

        // Login-item launches must not display any UI. Defer the first-time
        // automatic-update prompt until the next interactive launch.
        UpdaterManager.shared.start(allowsPermissionPrompt: !launchedAsLoginItem)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        manager.startAsync { [weak self] error in
            guard let self else { return }

            if let error = error {
                os_log(.error, log: self.log, "Failed to start: %{public}@", error.localizedDescription)
            } else {
                os_log(.info, log: self.log, "TrueTone Manager started")
            }

            // Login-item launches should stay silent during system startup. A
            // normal launch still opens Settings, including when the icon is
            // hidden.
            if !launchedAsLoginItem {
                DispatchQueue.main.async {
                    self.menuBarInterface.showSettings()
                }
            }
        }
    }

    private static var wasLaunchedAsLoginItem: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication &&
            event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Finder, Launchpad, and the Dock use this callback when launching an
        // instance that is already running.
        menuBarInterface?.showSettings()
        return true
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
