import XCTest
@testable import TrueToneManager

final class TrueToneManagerPreferenceTests: XCTestCase {
    var manager: TrueToneManager!
    var store: PreferenceStore!
    var temporaryDirectory: URL!

    override func setUpWithError() throws {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrueToneManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        store = PreferenceStore(preferencesURL: temporaryDirectory.appendingPathComponent("preferences.json"))
        manager = TrueToneManager(controller: nil, store: store, monitor: ApplicationMonitor())
    }

    override func tearDownWithError() throws {
        manager = nil
        store = nil
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testSetPreferencePersistsRule() throws {
        try manager.setPreference(
            bundleIdentifier: "com.example.app",
            displayName: "Example App",
            enabled: false
        )

        let stored = store.getPreference(for: "com.example.app")
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.bundleIdentifier, "com.example.app")
        XCTAssertEqual(stored?.displayName, "Example App")
        XCTAssertEqual(stored?.trueToneEnabled, false)
    }

    func testSetPreferenceReplacesExistingRule() throws {
        try manager.setPreference(
            bundleIdentifier: "com.example.app",
            displayName: "Example App",
            enabled: false
        )
        try manager.setPreference(
            bundleIdentifier: "com.example.app",
            displayName: "Example App Renamed",
            enabled: true
        )

        let stored = store.getPreference(for: "com.example.app")
        XCTAssertEqual(stored?.trueToneEnabled, true)
        XCTAssertEqual(stored?.displayName, "Example App Renamed")
        XCTAssertEqual(store.getAllPreferences().count, 1)
    }

    func testSetPreferenceWithEmptyBundleIdentifierThrows() {
        XCTAssertThrowsError(
            try manager.setPreference(bundleIdentifier: "", displayName: "Nameless", enabled: true)
        ) { error in
            XCTAssertEqual(error as? PreferenceStoreError, .invalidBundleIdentifier)
        }
    }

    func testRemovePreferenceRemovesRule() throws {
        try manager.setPreference(
            bundleIdentifier: "com.example.app",
            displayName: "Example App",
            enabled: true
        )
        XCTAssertNotNil(store.getPreference(for: "com.example.app"))

        try manager.removePreference(bundleIdentifier: "com.example.app")

        XCTAssertNil(store.getPreference(for: "com.example.app"))
        XCTAssertTrue(store.getAllPreferences().isEmpty)
    }

    func testRemovePreferenceWithEmptyBundleIdentifierThrows() {
        XCTAssertThrowsError(
            try manager.removePreference(bundleIdentifier: "")
        ) { error in
            XCTAssertEqual(error as? PreferenceStoreError, .invalidBundleIdentifier)
        }
    }

    func testSetPreferencePersistsAcrossStoreReload() throws {
        try manager.setPreference(
            bundleIdentifier: "wine:Z:\\Games\\Example.exe",
            displayName: "Example Game",
            enabled: false
        )

        let reloadedStore = PreferenceStore(
            preferencesURL: temporaryDirectory.appendingPathComponent("preferences.json")
        )
        try reloadedStore.loadPreferences()

        let stored = reloadedStore.getPreference(for: "wine:Z:\\Games\\Example.exe")
        XCTAssertEqual(stored?.trueToneEnabled, false)
        XCTAssertEqual(stored?.displayName, "Example Game")
    }
}
