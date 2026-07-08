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

    func testLoadDropsGarbageEntriesAndKeepsValidOnes() throws {
        let garbage = AppPreference(
            bundleIdentifier: "\u{01}\u{02}\u{7F}binary\u{00}junk",
            trueToneEnabled: true,
            displayName: "\u{03}\u{04}garbage"
        )
        let valid = AppPreference(
            bundleIdentifier: "com.example.valid",
            trueToneEnabled: false,
            displayName: "Valid App"
        )
        let wine = AppPreference(
            bundleIdentifier: "wine:Z:\\Games\\Example.exe",
            trueToneEnabled: true,
            displayName: "Example Game"
        )

        let collection = PreferenceCollection(preferences: [garbage, valid, wine])
        let data = try JSONEncoder().encode(collection)
        try data.write(to: temporaryDirectory.appendingPathComponent("preferences.json"))

        try store.loadPreferences()

        let all = store.getAllPreferences()
        XCTAssertEqual(all.count, 2)
        XCTAssertNil(store.getPreference(for: garbage.bundleIdentifier))
        XCTAssertEqual(store.getPreference(for: "com.example.valid")?.trueToneEnabled, false)
        XCTAssertEqual(store.getPreference(for: "wine:Z:\\Games\\Example.exe")?.trueToneEnabled, true)
    }

    func testSetPreferenceWithControlCharacterIdentifierThrows() {
        let pref = AppPreference(
            bundleIdentifier: "com.example\u{01}.bad",
            trueToneEnabled: true,
            displayName: "Bad App"
        )

        XCTAssertThrowsError(try store.setPreference(pref)) { error in
            XCTAssertEqual(error as? PreferenceStoreError, .invalidBundleIdentifier)
        }
        XCTAssertNil(store.getPreference(for: pref.bundleIdentifier))
    }

    func testSetPreferenceWithWineIdentifierSucceeds() {
        let pref = AppPreference(
            bundleIdentifier: "wine:Z:\\Users\\martin\\Games\\ZenlessZoneZero.exe",
            trueToneEnabled: false,
            displayName: "Zenless Zone Zero"
        )

        XCTAssertNoThrow(try store.setPreference(pref))
        XCTAssertEqual(store.getPreference(for: pref.bundleIdentifier)?.trueToneEnabled, false)
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
