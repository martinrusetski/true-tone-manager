import AppKit
import Foundation
import os.log
import UserNotifications

enum NotificationType {
    case error
    case success
    case info
}

class MenuBarInterface: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let manager: TrueToneManager
    private let log = OSLog(subsystem: "com.truetonemanager", category: "MenuBarInterface")
    private var isPerformingAction = false
    private lazy var aboutWindowController = AboutWindowController()

    init(manager: TrueToneManager) {
        self.manager = manager
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let image = NSImage(
                systemSymbolName: "sun.max",
                accessibilityDescription: "TrueTone Manager"
            ) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "☀"
            }

            button.target = self
            button.action = #selector(handleStatusBarButtonClick)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        menu.delegate = self
        updateMenu()
        os_log(.info, log: log, "Menu bar interface ready")
    }

    func teardown() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    @objc private func handleStatusBarButtonClick() {
        guard let button = statusItem.button else { return }

        updateMenu()

        button.isHighlighted = true
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? button.frame
        let menuPoint = NSPoint(x: buttonFrame.minX, y: buttonFrame.minY)
        menu.popUp(positioning: nil, at: menuPoint, in: nil)
        button.isHighlighted = false
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.button?.isHighlighted = false
    }

    func updateMenu() {
        menu.removeAllItems()

        let currentAppName = currentAppDisplayName()
        let pref = currentAppPreference()
        let isDisabled = pref?.trueToneEnabled == false
        let checkboxOn = !isDisabled

        let appItem = NSMenuItem(
            title: "Current App: \(currentAppName)",
            action: nil,
            keyEquivalent: ""
        )
        appItem.isEnabled = false
        menu.addItem(appItem)

        let stateItem = NSMenuItem(
            title: "TrueTone: \(manager.currentTrueToneState ? "On" : "Off")",
            action: nil,
            keyEquivalent: ""
        )
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        menu.addItem(.separator())

        let prefItem = NSMenuItem(
            title: "Enable TrueTone for \(currentAppName)",
            action: #selector(toggleAppPreferenceAction),
            keyEquivalent: ""
        )
        prefItem.target = self
        prefItem.state = checkboxOn ? .on : .off
        prefItem.isEnabled = !isPerformingAction
        menu.addItem(prefItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLoginAction),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.isEnabled() ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About TrueTone Manager",
            action: #selector(showAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "Quit TrueTone Manager",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func currentAppDisplayName() -> String {
        guard let current = manager.currentApplication else {
            return "Unknown"
        }

        let name = current.displayName
        if name.count > 30 {
            let index = name.index(name.startIndex, offsetBy: 27)
            return String(name[..<index]) + "..."
        }

        return name
    }

    private func currentAppPreference() -> AppPreference? {
        guard let current = manager.currentApplication else {
            return nil
        }
        return manager.preferenceStore.getPreference(for: current.bundleIdentifier)
    }

    @objc private func toggleAppPreferenceAction() {
        let currentlyDisabled = currentAppPreference()?.trueToneEnabled == false

        performAction {
            if currentlyDisabled {
                try self.manager.removePreferenceForCurrentApp()
            } else {
                try self.manager.setPreferenceForCurrentApp(enabled: false)
            }
        }
    }

    @objc private func toggleLaunchAtLoginAction() {
        let currentlyEnabled = LaunchAtLoginManager.isEnabled()

        do {
            if currentlyEnabled {
                try LaunchAtLoginManager.disable()
            } else {
                try LaunchAtLoginManager.enable()
            }
            updateMenu()
        } catch {
            showNotification(
                title: "Launch at Login Error",
                message: error.localizedDescription,
                type: .error
            )
        }
    }

    @objc private func quitAction() {
        manager.stop()
        teardown()
        NSApplication.shared.terminate(nil)
    }

    @objc private func showAboutAction() {
        aboutWindowController.show()
    }

    private func performAction(_ action: @escaping () throws -> Void) {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        updateMenu()

        DispatchQueue.global().async { [weak self] in
            defer {
                DispatchQueue.main.async {
                    self?.isPerformingAction = false
                    self?.updateMenu()
                }
            }

            do {
                try action()
            } catch {
                DispatchQueue.main.async {
                    self?.showNotification(
                        title: "Error",
                        message: error.localizedDescription,
                        type: .error
                    )
                }
            }
        }
    }

    func showNotification(title: String, message: String, type: NotificationType) {
        guard Bundle.main.bundleIdentifier != nil else {
            os_log(.info, log: log, "%{public}@: %{public}@", title, message)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        if type == .error {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
