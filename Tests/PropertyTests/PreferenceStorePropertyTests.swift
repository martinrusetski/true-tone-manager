import XCTest
import SwiftCheck
@testable import TrueToneManager

final class PreferenceStorePropertyTests: XCTestCase {
    private func temporaryPreferencesURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrueToneManagerPropertyTests-\(UUID().uuidString)")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("preferences.json")
    }

    func testProperty6_PreferenceUpsert() {
        property("Adding valid AppPreference persists it and subsequent queries return matching data") <- forAll(
            BundleIdentifierGenerator.arbitrary(),
            Bool.arbitrary,
            String.arbitrary
        ) { (bundleId: String, enabled: Bool, name: String) in
            let store = PreferenceStore(preferencesURL: self.temporaryPreferencesURL())
            let pref = AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: enabled,
                displayName: name
            )

            do {
                try store.setPreference(pref)
            } catch {
                return false
            }

            let retrieved = store.getPreference(for: bundleId)
            return retrieved?.bundleIdentifier == bundleId
                && retrieved?.trueToneEnabled == enabled
                && retrieved?.displayName == name
        }
    }

    func testProperty6b_PreferenceUpsertReplaces() {
        property("Adding a preference with existing bundle identifier replaces the old preference") <- forAll(
            BundleIdentifierGenerator.arbitrary(),
            String.arbitrary,
            String.arbitrary
        ) { (bundleId: String, name1: String, name2: String) in
            guard name1 != name2 else { return true }

            let store = PreferenceStore(preferencesURL: self.temporaryPreferencesURL())
            let pref1 = AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: true,
                displayName: name1
            )
            let pref2 = AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: false,
                displayName: name2
            )

            do {
                try store.setPreference(pref1)
                try store.setPreference(pref2)
            } catch {
                return false
            }

            let retrieved = store.getPreference(for: bundleId)
            return retrieved?.trueToneEnabled == false
                && retrieved?.displayName == name2
        }
    }

    func testProperty7_PreferenceDeletion() {
        property("Removing an existing preference results in subsequent queries returning nil") <- forAll(
            BundleIdentifierGenerator.arbitrary(),
            Bool.arbitrary,
            String.arbitrary
        ) { (bundleId: String, enabled: Bool, name: String) in
            guard !name.isEmpty else { return true }

            let store = PreferenceStore(preferencesURL: self.temporaryPreferencesURL())
            let pref = AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: enabled,
                displayName: name
            )

            do {
                try store.setPreference(pref)
                try store.removePreference(for: bundleId)
            } catch {
                return false
            }

            return store.getPreference(for: bundleId) == nil
        }
    }

    func testProperty25_PersistenceRoundTrip() {
        property("Save then load preserves bundle identifiers and TrueTone states") <- forAll(
            BundleIdentifierGenerator.arbitrary(),
            Bool.arbitrary
        ) { (bundleId: String, enabled: Bool) in
            let preferencesURL = self.temporaryPreferencesURL()
            let store = PreferenceStore(preferencesURL: preferencesURL)
            let pref = AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: enabled,
                displayName: bundleId
            )

            do {
                try store.setPreference(pref)
                try store.savePreferences()
            } catch {
                return false
            }

            let loadedStore = PreferenceStore(preferencesURL: preferencesURL)
            do {
                try loadedStore.loadPreferences()
            } catch {
                return false
            }

            let loaded = loadedStore.getPreference(for: bundleId)
            return loaded?.bundleIdentifier == bundleId
                && loaded?.trueToneEnabled == enabled
        }
    }

    func testEmptyBundleIdentifierRejection() {
        property("Empty bundle identifier is rejected") <- forAll { (enabled: Bool, name: String) in
            let store = PreferenceStore(preferencesURL: self.temporaryPreferencesURL())
            let pref = AppPreference(
                bundleIdentifier: "",
                trueToneEnabled: enabled,
                displayName: name
            )

            do {
                try store.setPreference(pref)
                return false
            } catch let error as PreferenceStoreError {
                return error == .invalidBundleIdentifier
            } catch {
                return false
            }
        }
    }

    func testGetAllPreferences() {
        property("getAllPreferences returns all added preferences") <- forAll { (prefs: [String]) in
            let uniqueIds = Array(Set(prefs))
            let store = PreferenceStore(preferencesURL: self.temporaryPreferencesURL())

            for (i, bundleId) in uniqueIds.enumerated() {
                guard !bundleId.isEmpty else { continue }
                let pref = AppPreference(
                    bundleIdentifier: bundleId,
                    trueToneEnabled: i % 2 == 0,
                    displayName: bundleId
                )
                try? store.setPreference(pref)
            }

            let all = store.getAllPreferences()
            return all.count <= uniqueIds.count && all.allSatisfy { !$0.bundleIdentifier.isEmpty }
        }
    }
}
