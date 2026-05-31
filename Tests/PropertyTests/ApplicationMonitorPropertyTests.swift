import XCTest
import SwiftCheck
@testable import TrueToneManager

final class MockApplicationMonitorClient: ApplicationMonitorSystemClient {
    var frontmostApp: (bundleIdentifier: String?, displayName: String?)? = ("com.test.app", "Test App")
    var notifications: [(String?, String?)] = []
    var observers: [(Any, Selector)] = []

    func frontmostApplication() -> (bundleIdentifier: String?, displayName: String?)? {
        return frontmostApp
    }

    func subscribeToAppChanges(observer: Any, selector: Selector) {
        observers.append((observer, selector))
    }

    func unsubscribeFromAppChanges(observer: Any) {
        observers.removeAll { $0.0 as AnyObject === observer as AnyObject }
    }

    func extractAppInfo(from notification: Notification) -> (bundleIdentifier: String?, displayName: String?)? {
        guard notifications.count > 0 else { return nil }
        let info = notifications.removeFirst()
        return info
    }
}

final class MockApplicationMonitorDelegate: ApplicationMonitorDelegate {
    var lastBundleId: String?
    var lastName: String?
    var lastError: ApplicationMonitorError?
    var changeCount = 0

    func applicationDidChange(bundleIdentifier: String, displayName: String) {
        lastBundleId = bundleIdentifier
        lastName = displayName
        changeCount += 1
    }

    func applicationMonitoringFailed(error: ApplicationMonitorError) {
        lastError = error
    }
}

final class ApplicationMonitorPropertyTests: XCTestCase {

    func testStartupDetectsCurrentApp() {
        let client = MockApplicationMonitorClient()
        client.frontmostApp = ("com.example.test", "Test")
        let delegate = MockApplicationMonitorDelegate()
        let monitor = ApplicationMonitor(systemClient: client)
        monitor.delegate = delegate

        monitor.start()

        XCTAssertEqual(delegate.lastBundleId, "com.example.test")
        XCTAssertEqual(delegate.lastName, "Test")
    }

    func testMissingBundleIdentifierReturnsNil() {
        let client = MockApplicationMonitorClient()
        client.frontmostApp = (nil, "NoBundle")
        let delegate = MockApplicationMonitorDelegate()
        let monitor = ApplicationMonitor(systemClient: client)
        monitor.delegate = delegate

        let result = monitor.getCurrentApplication()

        XCTAssertNil(result)
        XCTAssertEqual(delegate.lastError, .bundleIdentifierUnavailable)
    }

    func testMissingFrontmostApp() {
        let client = MockApplicationMonitorClient()
        client.frontmostApp = nil
        let delegate = MockApplicationMonitorDelegate()
        let monitor = ApplicationMonitor(systemClient: client)
        monitor.delegate = delegate

        let result = monitor.getCurrentApplication()

        XCTAssertNil(result)
        XCTAssertNil(delegate.lastBundleId)
    }
}
