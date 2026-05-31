import AppKit
import Foundation

protocol ApplicationMonitorDelegate: AnyObject {
    func applicationDidChange(bundleIdentifier: String, displayName: String)
    func applicationMonitoringFailed(error: ApplicationMonitorError)
}

protocol ApplicationMonitorSystemClient: AnyObject {
    func frontmostApplication() -> (bundleIdentifier: String?, displayName: String?)?
    func subscribeToAppChanges(observer: Any, selector: Selector)
    func unsubscribeFromAppChanges(observer: Any)
    func extractAppInfo(from notification: Notification) -> (bundleIdentifier: String?, displayName: String?)?
}

class ApplicationMonitor {
    weak var delegate: ApplicationMonitorDelegate?
    private let systemClient: ApplicationMonitorSystemClient

    private var debounceTimer: Timer?
    private var pendingBundleId: String?
    private var pendingDisplayName: String?
    private var lastReportedBundleId: String?

    init(systemClient: ApplicationMonitorSystemClient = NativeWorkspaceClient()) {
        self.systemClient = systemClient
    }

    func start() {
        systemClient.subscribeToAppChanges(observer: self, selector: #selector(handleWorkspaceNotification(_:)))

        if let (bundleId, name) = getCurrentApplication() {
            lastReportedBundleId = bundleId
            delegate?.applicationDidChange(bundleIdentifier: bundleId, displayName: name)
        }
    }

    func stop() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        systemClient.unsubscribeFromAppChanges(observer: self)
    }

    func getCurrentApplication() -> (bundleIdentifier: String, displayName: String)? {
        guard let appInfo = systemClient.frontmostApplication() else {
            return nil
        }

        guard let bundleId = appInfo.bundleIdentifier else {
            delegate?.applicationMonitoringFailed(error: .bundleIdentifierUnavailable)
            return nil
        }

        let displayName = appInfo.displayName ?? bundleId
        return (bundleId, displayName)
    }

    @objc private func handleWorkspaceNotification(_ notification: Notification) {
        guard let appInfo = systemClient.extractAppInfo(from: notification) else {
            delegate?.applicationMonitoringFailed(error: .workspaceUnavailable)
            return
        }

        guard let bundleId = appInfo.bundleIdentifier else {
            delegate?.applicationMonitoringFailed(error: .bundleIdentifierUnavailable)
            return
        }

        let displayName = appInfo.displayName ?? bundleId

        guard bundleId != lastReportedBundleId else {
            return
        }

        debounceTimer?.invalidate()

        pendingBundleId = bundleId
        pendingDisplayName = displayName

        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            guard let self = self,
                  let bundleId = self.pendingBundleId,
                  let displayName = self.pendingDisplayName else {
                return
            }

            self.lastReportedBundleId = bundleId
            self.delegate?.applicationDidChange(bundleIdentifier: bundleId, displayName: displayName)
        }
    }
}

final class NativeWorkspaceClient: ApplicationMonitorSystemClient {
    func frontmostApplication() -> (bundleIdentifier: String?, displayName: String?)? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return (app.bundleIdentifier, app.localizedName)
    }

    func subscribeToAppChanges(observer: Any, selector: Selector) {
        NSWorkspace.shared.notificationCenter.addObserver(
            observer,
            selector: selector,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func unsubscribeFromAppChanges(observer: Any) {
        NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }

    func extractAppInfo(from notification: Notification) -> (bundleIdentifier: String?, displayName: String?)? {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return nil
        }
        return (app.bundleIdentifier, app.localizedName)
    }
}
