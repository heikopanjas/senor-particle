import AranetKit
import Foundation
import UserNotifications
import os

/// Posts a user notification when a device with notifications enabled changes its status color.
///
/// Permission is requested when the user enables notifications for a device, and again before posting, which is a
/// no-op once the user has decided.
final class NotificationManager {
    private weak var sensorManager: SensorManager?
    private let preferences: PreferencesStore
    private var tracker = StatusTransitionTracker()

    init(sensorManager: SensorManager, preferences: PreferencesStore = .shared, notificationCenter: NotificationCenter = .default) {
        self.sensorManager = sensorManager
        self.preferences = preferences

        notificationCenter.addObserver(
            self,
            selector: #selector(self.handleDevicesDidChange(_:)),
            name: .sensorDevicesDidChange,
            object: sensorManager
        )
    }

    /// Asks for permission to post notifications; macOS prompts only while the user has not decided yet.
    @concurrent static func requestAuthorization() async -> Void {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
        catch {
            let message = error.localizedDescription
            Logger.notifications.error("Notification authorization failed: \(message, privacy: .public)")
        }
    }

    /// Whether the user turned notifications off for the app in System Settings.
    @concurrent static func isAuthorizationDenied() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    // MARK: - Private

    @objc private func handleDevicesDidChange(_ notification: Notification) -> Void {
        guard let deviceId = notification.userInfo?[SensorManager.deviceIdUserInfoKey] as? UUID else { return }
        guard let monitored = self.sensorManager?.devices[deviceId] else { return }

        let transition = self.tracker.evaluate(
            deviceId: deviceId,
            status: monitored.reading?.status,
            enabled: self.preferences.notificationsEnabled(for: deviceId)
        )
        guard let transition else { return }
        guard let reading = monitored.reading else { return }

        let content = StatusNotificationCopy.content(
            for: reading,
            title: self.preferences.displayName(for: monitored),
            transition: transition,
            personality: self.preferences.notificationPersonality,
            unitSystem: self.preferences.displayUnitSystem
        )
        guard let content else { return }

        let title = content.title
        let body = content.body
        Task {
            await Self.post(title: title, body: body)
        }
    }

    @concurrent private static func post(title: String, body: String) async -> Void {
        await Self.requestAuthorization()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        do {
            try await UNUserNotificationCenter.current().add(request)
        }
        catch {
            let message = error.localizedDescription
            Logger.notifications.error("Posting a notification failed: \(message, privacy: .public)")
        }
    }
}
