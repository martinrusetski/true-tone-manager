import AppKit
import SwiftUI

/// NSTabViewController with the .toolbar style does not reliably propagate the
/// selected tab's label to the window title, so mirror it manually both at
/// initial display and on every selection change.
private class SettingsTabViewController: NSTabViewController {
    override var selectedTabViewItemIndex: Int {
        didSet {
            updateWindowTitle()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateWindowTitle()
    }

    private func updateWindowTitle() {
        guard tabViewItems.indices.contains(selectedTabViewItemIndex) else { return }
        view.window?.title = tabViewItems[selectedTabViewItemIndex].label
    }
}

class SettingsWindowController: NSWindowController {
    private var hasShownOnce = false

    convenience init() {
        let tabViewController = SettingsTabViewController()
        tabViewController.tabStyle = .toolbar

        // Both panes share one size so the window doesn't resize on tab switch.
        // The height accommodates the taller grouped-Form rows and switches
        // introduced in the macOS 26/27 UI; the General pane also scrolls as a
        // safety net so its bottom controls can never be clipped.
        let paneSize = NSSize(width: 480, height: 460)

        let generalController = NSHostingController(rootView: GeneralSettingsView())
        generalController.preferredContentSize = paneSize
        let generalItem = NSTabViewItem(viewController: generalController)
        generalItem.label = "General"
        generalItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
        tabViewController.addTabViewItem(generalItem)

        let appsController = NSHostingController(rootView: AppRulesSettingsView())
        appsController.preferredContentSize = paneSize
        let appsItem = NSTabViewItem(viewController: appsController)
        appsItem.label = "Apps"
        appsItem.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "Apps")
        tabViewController.addTabViewItem(appsItem)

        let window = NSWindow(contentViewController: tabViewController)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.title = "General"

        self.init(window: window)
    }

    func show() {
        if !hasShownOnce {
            window?.center()
            hasShownOnce = true
        }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
