import Foundation
import os.log
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private let log = OSLog(subsystem: "com.truetonemanager", category: "Notifications")
    private var shownErrorTypes: Set<String> = []
    private let deduplicationQueue = DispatchQueue(label: "com.truetonemanager.notifications")

    private static let stateChangeNotificationsKey = "StateChangeNotificationsEnabled"

    /// Whether to post a notification each time True Tone turns on or off.
    /// Off by default (UserDefaults.bool defaults to false).
    var stateChangeNotificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.stateChangeNotificationsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.stateChangeNotificationsKey) }
    }

    private init() {}

    /// Post a notification, requesting authorization lazily the first time one is
    /// actually shown rather than up front at launch. If the user hasn't been
    /// asked yet we prompt now and only deliver once granted; if they've already
    /// granted we deliver straight away; if denied we stay silent.
    private func post(_ content: UNMutableNotificationContent) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error = error {
                        os_log(.error, log: self?.log ?? .default,
                               "Notification authorization failed: %{public}@", error.localizedDescription)
                    }
                    guard granted else { return }
                    self?.deliver(content, via: center)
                }
            case .authorized, .provisional, .ephemeral:
                self?.deliver(content, via: center)
            default:
                break
            }
        }
    }

    private func deliver(_ content: UNMutableNotificationContent, via center: UNUserNotificationCenter) {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
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

        post(content)
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

        post(content)
    }

    /// Post a notification that True Tone just turned on or off. Respects the
    /// user's toggle; does nothing when state-change notifications are disabled.
    func notifyTrueToneChanged(enabled: Bool) {
        guard stateChangeNotificationsEnabled else { return }
        showNotification(
            title: "True Tone",
            message: enabled ? "True Tone turned on" : "True Tone turned off",
            type: .info
        )
    }

    func resetDeduplication() {
        deduplicationQueue.sync {
            shownErrorTypes.removeAll()
        }
    }
}
