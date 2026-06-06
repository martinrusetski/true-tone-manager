import Foundation
import ServiceManagement

enum LaunchAtLoginError: Error {
    case registrationFailed
    case unregistrationFailed
}

enum LaunchAtLoginManager {
    private static let userDefaultsKey = "LaunchAtLoginEnabled"

    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    static func isDesiredEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    static func enable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
        }
    }

    static func disable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.unregister()
            UserDefaults.standard.set(false, forKey: userDefaultsKey)
        }
    }
}
