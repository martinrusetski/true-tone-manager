import Foundation
import os.log
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private let log = OSLog(subsystem: "com.truetonemanager", category: "Notifications")
    private var shownErrorTypes: Set<String> = []
    private let deduplicationQueue = DispatchQueue(label: "com.truetonemanager.notifications")

    private init() {}

    func requestAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else {
            os_log(.info, log: log, "Skipping notification authorization - no bundle identifier")
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                os_log(.error, log: self.log, "Notification authorization failed: %{public}@", error.localizedDescription)
            }
        }
    }

    func showError(type: String, title: String, message: String, deduplicate: Bool = true) {
        guard Bundle.main.bundleIdentifier != nil else {
            os_log(.error, log: log, "%{public}@: %{public}@", title, message)
            return
        }

        if deduplicate {
            let shouldShow = deduplicationQueue.sync { () -> Bool in
                if shownErrorTypes.contains(type) {
                    return false
                }
                shownErrorTypes.insert(type)
                return true
            }
            guard shouldShow else {
                os_log(.debug, log: log, "Suppressed duplicate error: %{public}@", type)
                return
            }
        }

        os_log(.error, log: log, "%{public}@: %{public}@", title, message)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func showNotification(title: String, message: String, type: NotificationType) {
        guard Bundle.main.bundleIdentifier != nil else {
            os_log(.info, log: log, "%{public}@: %{public}@", title, message)
            return
        }

        os_log(.info, log: log, "%{public}@: %{public}@", title, message)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        if type == .error {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func resetDeduplication() {
        deduplicationQueue.sync {
            shownErrorTypes.removeAll()
        }
    }
}
