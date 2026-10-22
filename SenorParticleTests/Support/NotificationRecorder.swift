import Foundation

/// Records every notification of one name posted to one center.
final class NotificationRecorder: NSObject {
    private(set) var notifications: [Notification] = []

    init(name: Notification.Name, center: NotificationCenter) {
        super.init()
        center.addObserver(self, selector: #selector(self.record(_:)), name: name, object: nil)
    }

    /// The `userInfo` value stored under `key` in each recorded notification that carries one.
    func userInfoValues<Value>(forKey key: String, as type: Value.Type) -> [Value] {
        return self.notifications.compactMap { $0.userInfo?[key] as? Value }
    }

    @objc private func record(_ notification: Notification) -> Void {
        self.notifications.append(notification)
    }
}
