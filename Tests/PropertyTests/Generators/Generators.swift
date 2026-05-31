import SwiftCheck
@testable import TrueToneManager
import Foundation

struct BundleIdentifierGenerator {
    static func arbitrary() -> Gen<String> {
        let components = Gen<String>.fromElements(of: ["com", "org", "io", "net", "dev"])
        let vendor = Gen<String>.fromElements(of: [
            "apple", "adobe", "microsoft", "google", "mozilla",
            "spotify", "slack", "figma", "jetbrains", "atlassian"
        ])
        let app = Gen<String>.fromElements(of: [
            "Safari", "Photoshop", "Word", "Chrome", "Firefox",
            "Xcode", "Terminal", "Finder", "Preview", "Mail"
        ])
        return Gen.zip(components, vendor, app).map { c, v, a in
            "\(c).\(v).\(a)"
        }
    }

    static func arbitraryNonEmpty() -> Gen<String> {
        return arbitrary().suchThat { !$0.isEmpty }
    }
}

struct AppPreferenceGenerator {
    static func arbitrary() -> Gen<AppPreference> {
        return Gen.zip(
            BundleIdentifierGenerator.arbitrary(),
            Bool.arbitrary,
            String.arbitrary.suchThat { !$0.isEmpty }
        ).map { bundleId, enabled, name in
            AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: enabled,
                displayName: name
            )
        }
    }

    static func arbitraryValid() -> Gen<AppPreference> {
        return Gen.zip(
            BundleIdentifierGenerator.arbitraryNonEmpty(),
            Bool.arbitrary
        ).map { bundleId, enabled in
            AppPreference(
                bundleIdentifier: bundleId,
                trueToneEnabled: enabled,
                displayName: bundleId
            )
        }
    }
}

struct PreferenceCollectionGenerator {
    static func arbitrary(maxSize: Int = 10) -> Gen<[AppPreference]> {
        return Gen.sized { size in
            let count = min(size, maxSize)
            let generators = (0..<max(1, count)).map { _ in
                AppPreferenceGenerator.arbitrary()
            }
            return sequence(generators)
        }
    }
}

struct TrueToneStateGenerator {
    static func arbitrary() -> Gen<Bool> {
        return Bool.arbitrary
    }

    static func stateCombinations() -> Gen<(Bool, Bool)> {
        return Gen.zip(Bool.arbitrary, Bool.arbitrary)
    }
}

struct ErrorScenarioGenerator {
    static let errorTypes: [String] = [
        "unsupportedHardware",
        "permissionDenied",
        "systemAPIError",
        "fileReadError",
        "fileWriteError",
        "corruptedData"
    ]

    static func arbitrary() -> Gen<String> {
        return Gen<String>.fromElements(of: errorTypes)
    }
}
