import XCTest
import SwiftCheck
@testable import TrueToneManager

final class TrueToneManagerPropertyTests: XCTestCase {
    private func temporaryPreferenceStore() -> PreferenceStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrueToneManagerPropertyTests-\(UUID().uuidString)")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let preferencesURL = directory.appendingPathComponent("preferences.json")
        return PreferenceStore(preferencesURL: preferencesURL)
    }

    func testProperty9_AutomaticAdjustment() {
        property("App change with existing preference applies the specified TrueTone state") <- forAll { (bundleId: String, preferredState: Bool) in
            guard !bundleId.isEmpty else { return true }

            let client = MockTrueToneSystemClient()
            client.currentState = !preferredState
            let controller = TrueToneController(systemClient: client)
            let store = self.temporaryPreferenceStore()

            let pref = AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: preferredState,
                displayName: bundleId
            )
            try? store.setPreference(pref)

            let manager = TrueToneManager(
                controller: controller,
                store: store,
                monitor: ApplicationMonitor()
            )
            manager.currentTrueToneState = !preferredState

            manager.handleApplicationChange(bundleIdentifier: bundleId)

            return manager.currentTrueToneState == preferredState
        }
    }

    func testProperty10_NoChangeOptimization() {
        property("App change where preference matches current state does not request state change") <- forAll { (bundleId: String, state: Bool) in
            guard !bundleId.isEmpty else { return true }

            let client = MockTrueToneSystemClient()
            client.currentState = state
            let controller = TrueToneController(systemClient: client)
            let store = self.temporaryPreferenceStore()

            let pref = AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: state,
                displayName: bundleId
            )
            try? store.setPreference(pref)

            let callsBefore = client.setStateCalls.count
            let manager = TrueToneManager(
                controller: controller,
                store: store,
                monitor: ApplicationMonitor()
            )
            manager.currentTrueToneState = state
            manager.handleApplicationChange(bundleIdentifier: bundleId)

            return client.setStateCalls.count == callsBefore
        }
    }

    func testProperty11_AppliesBaselineDefaultWithoutPreference() {
        property("App change without a rule applies the configured baseline default") <- forAll { (bundleId: String, initialState: Bool, baseline: Bool) in
            guard !bundleId.isEmpty else { return true }

            let client = MockTrueToneSystemClient()
            client.currentState = initialState
            let controller = TrueToneController(systemClient: client)
            let store = self.temporaryPreferenceStore()

            let manager = TrueToneManager(
                controller: controller,
                store: store,
                monitor: ApplicationMonitor()
            )
            manager.defaultTrueToneState = baseline
            manager.currentTrueToneState = initialState
            manager.handleApplicationChange(bundleIdentifier: bundleId)

            return manager.currentTrueToneState == baseline
                && client.currentState == baseline
        }
    }

    func testUnavailableDisplayLeavesStateUnchanged() {
        let bundleId = "com.test.app"
        let client = MockTrueToneSystemClient()
        client.supported = true
        client.available = false
        client.currentState = true
        let controller = TrueToneController(systemClient: client)
        let store = temporaryPreferenceStore()

        try? store.setPreference(
            AppPreference(bundleIdentifier: bundleId, trueToneEnabled: false, displayName: bundleId)
        )

        let manager = TrueToneManager(controller: controller, store: store, monitor: ApplicationMonitor())
        manager.currentTrueToneState = true
        let callsBefore = client.setStateCalls.count

        manager.handleApplicationChange(bundleIdentifier: bundleId)

        // No capable display active: rule is skipped, state untouched.
        XCTAssertEqual(client.setStateCalls.count, callsBefore)
        XCTAssertTrue(manager.currentTrueToneState)
    }

    func testRemovingRuleRestoresDefault() {
        let bundleId = "com.test.app"
        let client = MockTrueToneSystemClient()
        client.currentState = false
        let controller = TrueToneController(systemClient: client)
        let store = temporaryPreferenceStore()

        try? store.setPreference(
            AppPreference(bundleIdentifier: bundleId, trueToneEnabled: false, displayName: bundleId)
        )

        let manager = TrueToneManager(controller: controller, store: store, monitor: ApplicationMonitor())
        manager.defaultTrueToneState = true
        manager.currentTrueToneState = false

        // Simulate this app being frontmost, then removing its rule.
        manager.applicationDidChange(bundleIdentifier: bundleId, displayName: bundleId)
        try? manager.removePreferenceForCurrentApp()

        XCTAssertNil(store.getPreference(for: bundleId))
        XCTAssertTrue(manager.currentTrueToneState)
        XCTAssertEqual(client.currentState, true)
    }
}
