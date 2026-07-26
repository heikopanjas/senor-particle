import AranetKit
import Foundation
import UserNotifications

class NotificationManager {
    private weak var sensorManager: SensorManager?
    private var previousStatuses: [UUID: AranetStatusColor] = [:]

    init(sensorManager: SensorManager) {
        self.sensorManager = sensorManager

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { NSLog("[NotificationManager] Authorization error: %@", error.localizedDescription) }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleReadingDidUpdate),
            name: .aranetReadingDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Private

    @objc private func handleReadingDidUpdate() -> Void {
        guard let devices = self.sensorManager?.sortedDevices else { return }

        for device in devices {
            let id = device.device.id

            guard NotificationPreferences.isEnabled(for: id),
                let reading = device.reading,
                let newStatus = reading.status
            else {
                // Clear stored status so re-enabling doesn't fire a spurious transition
                self.previousStatuses.removeValue(forKey: id)
                continue
            }

            if let previous = self.previousStatuses[id], previous != newStatus {
                self.deliver(reading: reading, deviceId: id, from: previous, to: newStatus)
            }

            self.previousStatuses[id] = newStatus
        }
    }

    private func deliver(
        reading: AranetReading,
        deviceId: UUID,
        from previous: AranetStatusColor,
        to current: AranetStatusColor
    ) -> Void {
        guard
            let notification = StatusNotificationCopy.content(
                for: reading,
                deviceId: deviceId,
                from: previous,
                to: current
            )
        else { return }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error { NSLog("[NotificationManager] Failed to post notification: %@", error.localizedDescription) }
        }
    }
}
