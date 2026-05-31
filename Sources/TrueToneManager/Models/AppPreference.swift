import Foundation

struct AppPreference: Codable, Equatable {
    let bundleIdentifier: String
    let trueToneEnabled: Bool
    let displayName: String
    let dateModified: Date

    init(bundleIdentifier: String, trueToneEnabled: Bool, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.trueToneEnabled = trueToneEnabled
        self.displayName = displayName
        self.dateModified = Date()
    }
}
