import Foundation

enum TrueToneControllerError: Error, Equatable {
    case unsupportedHardware
    case permissionDenied(requiredPermission: String)
    case systemAPIError(message: String)
    case stateVerificationFailed
}
