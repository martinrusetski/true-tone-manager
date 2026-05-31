import XCTest
@testable import TrueToneManager

final class PreferenceStoreTests: XCTestCase {
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
    }

    override func tearDownWithError() throws {
        store = nil
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testSetAndGetPreference() {
        let pref = AppPreference(
            bundleIdentifier: "com.example.test",
            trueToneEnabled: false,
            displayName: "Example Test"
        )

        XCTAssertNoThrow(try store.setPreference(pref))

        let result = store.getPreference(for: "com.example.test")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.bundleIdentifier, "com.example.test")
        XCTAssertEqual(result?.trueToneEnabled, false)
    }

    func testRemoveNonExistentPreference() {
        let result = store.getPreference(for: "com.nonexistent")
        XCTAssertNil(result)

        XCTAssertNoThrow(try store.removePreference(for: "com.nonexistent"))
    }

    func testEmptyPreferenceCollection() {
        let all = store.getAllPreferences()
        XCTAssertTrue(all.isEmpty)
    }

    func testDuplicateBundleIdentifierReplaces() {
        let pref1 = AppPreference(
            bundleIdentifier: "com.test.duplicate",
            trueToneEnabled: false,
            displayName: "Original"
        )

        try? store.setPreference(pref1)

        let pref2 = AppPreference(
            bundleIdentifier: "com.test.duplicate",
            trueToneEnabled: true,
            displayName: "Replacement"
        )

        try? store.setPreference(pref2)

        let result = store.getPreference(for: "com.test.duplicate")
        XCTAssertEqual(result?.trueToneEnabled, true)
        XCTAssertEqual(result?.displayName, "Replacement")
    }
}
