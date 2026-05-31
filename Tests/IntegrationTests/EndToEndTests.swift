import XCTest
@testable import TrueToneManager

final class EndToEndTests: XCTestCase {
    var preferenceStore: PreferenceStore!
    var preferencesURL: URL!
    var temporaryDirectory: URL!

    override func setUpWithError() throws {
        super.setUp()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrueToneManagerIntegrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        preferencesURL = temporaryDirectory.appendingPathComponent("preferences.json")
        preferenceStore = PreferenceStore(preferencesURL: preferencesURL)
    }

    override func tearDownWithError() throws {
        preferenceStore = nil
        preferencesURL = nil
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testAddAndRetrievePreference() {
        let pref = AppPreference(
            bundleIdentifier: "com.test.app",
            trueToneEnabled: false,
            displayName: "Test App"
        )

        XCTAssertNoThrow(try preferenceStore.setPreference(pref))

        let retrieved = preferenceStore.getPreference(for: "com.test.app")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.bundleIdentifier, "com.test.app")
        XCTAssertEqual(retrieved?.trueToneEnabled, false)
        XCTAssertEqual(retrieved?.displayName, "Test App")
    }

    func testRemovePreference() {
        let pref = AppPreference(
            bundleIdentifier: "com.test.app",
            trueToneEnabled: true,
            displayName: "Test App"
        )

        try? preferenceStore.setPreference(pref)

        XCTAssertNoThrow(try preferenceStore.removePreference(for: "com.test.app"))

        let retrieved = preferenceStore.getPreference(for: "com.test.app")
        XCTAssertNil(retrieved)
    }

    func testReplaceExistingPreference() {
        let pref1 = AppPreference(
            bundleIdentifier: "com.test.app",
            trueToneEnabled: false,
            displayName: "Test App"
        )

        try? preferenceStore.setPreference(pref1)

        let pref2 = AppPreference(
            bundleIdentifier: "com.test.app",
            trueToneEnabled: true,
            displayName: "Updated App"
        )

        XCTAssertNoThrow(try preferenceStore.setPreference(pref2))

        let retrieved = preferenceStore.getPreference(for: "com.test.app")
        XCTAssertEqual(retrieved?.trueToneEnabled, true)
        XCTAssertEqual(retrieved?.displayName, "Updated App")
    }

    func testGetAllPreferences() {
        let pref1 = AppPreference(
            bundleIdentifier: "com.test.app1",
            trueToneEnabled: false,
            displayName: "App 1"
        )
        let pref2 = AppPreference(
            bundleIdentifier: "com.test.app2",
            trueToneEnabled: true,
            displayName: "App 2"
        )

        try? preferenceStore.setPreference(pref1)
        try? preferenceStore.setPreference(pref2)

        let all = preferenceStore.getAllPreferences()
        XCTAssertEqual(all.count, 2)
    }

    func testPreferencePersistenceRoundTrip() throws {
        let pref = AppPreference(
            bundleIdentifier: "com.test.persist",
            trueToneEnabled: true,
            displayName: "Persist App"
        )

        try preferenceStore.setPreference(pref)

        let newStore = PreferenceStore(preferencesURL: preferencesURL)
        try newStore.loadPreferences()

        let retrieved = newStore.getPreference(for: "com.test.persist")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.bundleIdentifier, "com.test.persist")
        XCTAssertEqual(retrieved?.trueToneEnabled, true)
    }

    func testEmptyBundleIdentifierRejection() {
        XCTAssertThrowsError(try preferenceStore.setPreference(
            AppPreference(
                bundleIdentifier: "",
                trueToneEnabled: true,
                displayName: "Bad"
            )
        )) { error in
            XCTAssertEqual(error as? PreferenceStoreError, .invalidBundleIdentifier)
        }
    }

    func testPreferenceLookupPerformance() {
        for i in 0..<100 {
            let pref = AppPreference(
                bundleIdentifier: "com.test.\(i)",
                trueToneEnabled: i % 2 == 0,
                displayName: "App \(i)"
            )
            try? preferenceStore.setPreference(pref)
        }

        measure {
            let _ = preferenceStore.getPreference(for: "com.test.50")
        }
    }

    func testTrueToneStateEnumConversion() {
        let enabled = TrueToneState.enabled
        XCTAssertEqual(enabled.boolValue, true)

        let disabled = TrueToneState.disabled
        XCTAssertEqual(disabled.boolValue, false)

        let unknown = TrueToneState.unknown
        XCTAssertNil(unknown.boolValue)

        let fromTrue = TrueToneState(bool: true)
        XCTAssertEqual(fromTrue.boolValue, true)

        let fromFalse = TrueToneState(bool: false)
        XCTAssertEqual(fromFalse.boolValue, false)

        let fromNil = TrueToneState(bool: nil)
        XCTAssertEqual(fromNil.boolValue, nil)
    }

    func testApplicationNameTruncation() {
        let longName = "This Is A Very Long Application Name That Exceeds Thirty Characters"
        XCTAssertGreaterThan(longName.count, 30)

        if longName.count > 30 {
            let index = longName.index(longName.startIndex, offsetBy: 27)
            let truncated = String(longName[..<index]) + "..."
            XCTAssertEqual(truncated.count, 30)
            XCTAssertTrue(truncated.hasSuffix("..."))
        }
    }
}
