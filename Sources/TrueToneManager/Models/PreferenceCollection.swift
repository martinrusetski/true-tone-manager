import Foundation

struct PreferenceCollection: Codable {
    let version: Int
    var preferences: [AppPreference]

    static let currentVersion = 1

    init() {
        self.version = PreferenceCollection.currentVersion
        self.preferences = []
    }
}
