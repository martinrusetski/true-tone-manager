import Foundation

enum MenuBarIconManager {
    static let didChangeVisibility = Notification.Name("com.truetonemanager.menuBarIconVisibilityDidChange")

    private static let hiddenKey = "HideMenuBarIcon"

    static var isHidden: Bool {
        get { UserDefaults.standard.bool(forKey: hiddenKey) }
        set {
            guard isHidden != newValue else { return }
            UserDefaults.standard.set(newValue, forKey: hiddenKey)
            NotificationCenter.default.post(name: didChangeVisibility, object: nil)
        }
    }
}
