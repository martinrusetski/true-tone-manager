import Foundation

enum PreferenceStoreError: Error, Equatable {
    case invalidBundleIdentifier
    case fileReadError(message: String)
    case fileWriteError(message: String)
    case corruptedData
}
