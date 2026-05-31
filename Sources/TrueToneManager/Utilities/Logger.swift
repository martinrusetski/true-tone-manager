import Foundation
import os.log

class Logger {
    static let shared = Logger()

    private let log = OSLog(subsystem: "com.truetonemanager", category: "General")

    private init() {}

    func info(_ message: String) {
        os_log(.info, log: log, "%{public}@", message)
    }

    func error(_ message: String) {
        os_log(.error, log: log, "%{public}@", message)
    }

    func debug(_ message: String) {
        os_log(.debug, log: log, "%{public}@", message)
    }
}
