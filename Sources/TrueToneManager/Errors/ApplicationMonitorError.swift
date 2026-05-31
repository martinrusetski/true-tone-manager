import Foundation

enum ApplicationMonitorError: Error, Equatable {
    case workspaceUnavailable
    case bundleIdentifierUnavailable
    case permissionDenied
}
