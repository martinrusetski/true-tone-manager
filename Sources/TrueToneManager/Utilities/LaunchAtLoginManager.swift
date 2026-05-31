import Foundation
import ServiceManagement

enum LaunchAtLoginError: Error {
    case registrationFailed
    case unregistrationFailed
}

enum LaunchAtLoginManager {
    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    static func enable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
        }
    }

    static func disable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.unregister()
        }
    }
}
