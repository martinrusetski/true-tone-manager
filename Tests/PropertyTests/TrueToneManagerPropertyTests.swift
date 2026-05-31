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

    func testProperty11_DefaultsToTrueToneOnWithoutPreference() {
        property("App change without preference enables TrueTone by default") <- forAll { (bundleId: String, initialState: Bool) in
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
            manager.currentTrueToneState = initialState
            manager.handleApplicationChange(bundleIdentifier: bundleId)

            return manager.currentTrueToneState == true
                && client.currentState == true
        }
    }
}
