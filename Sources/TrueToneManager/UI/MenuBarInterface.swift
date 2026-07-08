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
    private lazy var settingsWindowController = SettingsWindowController()

    init(manager: TrueToneManager) {
        self.manager = manager
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleStatusBarButtonClick)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        }

        menu.delegate = self

        // Keep the menu in sync with edits made from the Settings window.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreferencesDidChange),
            name: .preferencesDidChange,
            object: nil
        )

        updateMenu()
        os_log(.info, log: log, "Menu bar interface ready")
    }

    func teardown() {
        NotificationCenter.default.removeObserver(self, name: .preferencesDidChange, object: nil)
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    @objc private func handlePreferencesDidChange() {
        updateMenu()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let symbolName = manager.currentTrueToneState ? "sun.max.fill" : "sun.max"

        if let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "TrueTone Manager"
        ) {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.title = "☀"
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
        updateIcon()
        menu.removeAllItems()

        let currentAppName = currentAppDisplayName()
        let available = manager.isTrueToneAvailable

        let appItem = NSMenuItem(
            title: "Current App: \(currentAppName)",
            action: nil,
            keyEquivalent: ""
        )
        appItem.isEnabled = false
        menu.addItem(appItem)

        let stateText: String
        if !available {
            stateText = "Unavailable"
        } else {
            stateText = manager.currentTrueToneState ? "On" : "Off"
        }
        let stateItem = NSMenuItem(
            title: "TrueTone: \(stateText)",
            action: nil,
            keyEquivalent: ""
        )
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        if !available {
            let hintItem = NSMenuItem(
                title: "No True Tone-capable display is active",
                action: nil,
                keyEquivalent: ""
            )
            hintItem.isEnabled = false
            menu.addItem(hintItem)
        }

        menu.addItem(.separator())

        menu.addItem(makeAppRuleSubmenu(appName: currentAppName))
        menu.addItem(makeDefaultSubmenu())

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        if UpdaterManager.shared.isAvailable {
            let updatesItem = NSMenuItem(
                title: "Check for Updates…",
                action: #selector(checkForUpdatesAction),
                keyEquivalent: ""
            )
            updatesItem.target = self
            menu.addItem(updatesItem)
        }

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

    private func makeAppRuleSubmenu(appName: String) -> NSMenuItem {
        let pref = currentAppPreference()
        let submenu = NSMenu()

        let defaultText = manager.defaultTrueToneState ? "On" : "Off"
        let useDefault = NSMenuItem(
            title: "Use Default (\(defaultText))",
            action: #selector(useDefaultRuleAction),
            keyEquivalent: ""
        )
        useDefault.target = self
        useDefault.state = (pref == nil) ? .on : .off
        submenu.addItem(useDefault)

        let alwaysOn = NSMenuItem(title: "Always On", action: #selector(setRuleOnAction), keyEquivalent: "")
        alwaysOn.target = self
        alwaysOn.state = (pref?.trueToneEnabled == true) ? .on : .off
        submenu.addItem(alwaysOn)

        let alwaysOff = NSMenuItem(title: "Always Off", action: #selector(setRuleOffAction), keyEquivalent: "")
        alwaysOff.target = self
        alwaysOff.state = (pref?.trueToneEnabled == false) ? .on : .off
        submenu.addItem(alwaysOff)

        let item = NSMenuItem(title: "TrueTone for \(appName)", action: nil, keyEquivalent: "")
        item.submenu = submenu
        item.isEnabled = !isPerformingAction && manager.currentApplication != nil
        return item
    }

    private func makeDefaultSubmenu() -> NSMenuItem {
        let submenu = NSMenu()

        let on = NSMenuItem(title: "On", action: #selector(setDefaultOnAction), keyEquivalent: "")
        on.target = self
        on.state = manager.defaultTrueToneState ? .on : .off
        submenu.addItem(on)

        let off = NSMenuItem(title: "Off", action: #selector(setDefaultOffAction), keyEquivalent: "")
        off.target = self
        off.state = manager.defaultTrueToneState ? .off : .on
        submenu.addItem(off)

        let item = NSMenuItem(title: "Default (apps without a rule)", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    @objc private func useDefaultRuleAction() {
        performAction { try self.manager.removePreferenceForCurrentApp() }
    }

    @objc private func setRuleOnAction() {
        performAction { try self.manager.setPreferenceForCurrentApp(enabled: true) }
    }

    @objc private func setRuleOffAction() {
        performAction { try self.manager.setPreferenceForCurrentApp(enabled: false) }
    }

    @objc private func setDefaultOnAction() {
        manager.setDefaultTrueTone(enabled: true)
        updateMenu()
    }

    @objc private func setDefaultOffAction() {
        manager.setDefaultTrueTone(enabled: false)
        updateMenu()
    }

    @objc private func showSettingsAction() {
        settingsWindowController.show()
    }

    @objc private func quitAction() {
        manager.stop()
        teardown()
        NSApplication.shared.terminate(nil)
    }

    @objc private func showAboutAction() {
        aboutWindowController.show()
    }

    @objc private func checkForUpdatesAction() {
        UpdaterManager.shared.checkForUpdates()
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
