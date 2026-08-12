import Foundation

struct AppPreference: Codable, Equatable, Identifiable {
    let bundleIdentifier: String
    /// `nil` keeps the app in the list while following the global default.
    let trueToneEnabled: Bool?
    let displayName: String
    let dateModified: Date

    var id: String { bundleIdentifier }

    init(bundleIdentifier: String, trueToneEnabled: Bool?, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.trueToneEnabled = trueToneEnabled
        self.displayName = displayName
        self.dateModified = Date()
    }
}
