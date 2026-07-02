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
        return identify(app)
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
        return identify(app)
    }

    /// Map a running application to a stable identifier and display name.
    ///
    /// Normal macOS apps expose a bundle identifier, which we use directly.
    /// Windows programs run under Wine (CrossOver, Whisky, Yaagl, etc.) have no
    /// bundle identifier and all present themselves as a process named "wine",
    /// so keying on the bundle id would drop them entirely and keying on the
    /// name would merge every Wine app into one. Instead we key them on the real
    /// Windows executable path pulled from the process arguments, which is
    /// unique per game and stable across launches.
    private func identify(_ app: NSRunningApplication) -> (bundleIdentifier: String?, displayName: String?) {
        if let bundleId = app.bundleIdentifier {
            return (bundleId, app.localizedName)
        }

        if let exePath = Self.windowsExecutablePath(pid: app.processIdentifier) {
            return ("wine:\(exePath)", Self.displayName(localizedName: app.localizedName, exePath: exePath))
        }

        return (nil, app.localizedName)
    }

    /// Prefer the Wine-provided app name (e.g. "Zenless Zone Zero"), but fall
    /// back to the executable's base name when the process still reports the
    /// generic "wine" (which happens before Wine sets the real name).
    private static func displayName(localizedName: String?, exePath: String) -> String {
        if let name = localizedName, !name.isEmpty, name.lowercased() != "wine" {
            return name
        }
        let base = exePath.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? exePath
        return base.hasSuffix(".exe") ? String(base.dropLast(4)) : base
    }

    /// Read `argv[0]` for a process via `KERN_PROCARGS2` and return it only when
    /// it looks like a Windows executable path (ends in ".exe"). Wine sets
    /// `argv[0]` of the game process to the launched ".exe", e.g.
    /// `Z:\Users\...\ZenlessZoneZero.exe`.
    private static func windowsExecutablePath(pid: pid_t) -> String? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else {
            return nil
        }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        var argc: Int32 = 0
        withUnsafeMutableBytes(of: &argc) { $0.copyBytes(from: buffer[0..<MemoryLayout<Int32>.size]) }
        guard argc > 0 else { return nil }

        // Layout: [argc][exec_path\0][padding \0...][argv[0]\0][argv[1]\0]...
        var index = MemoryLayout<Int32>.size
        while index < buffer.count, buffer[index] != 0 { index += 1 }  // skip exec_path
        while index < buffer.count, buffer[index] == 0 { index += 1 }  // skip padding

        let start = index
        while index < buffer.count, buffer[index] != 0 { index += 1 }  // read argv[0]
        guard index > start else { return nil }

        let argv0 = String(decoding: buffer[start..<index], as: UTF8.self)
        return argv0.lowercased().hasSuffix(".exe") ? argv0 : nil
    }
}
