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
            selector: #selector(handleSensorUpdate),
            name: .aranetSensorDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Private

    @objc private func handleSensorUpdate() {
        guard let devices = sensorManager?.sortedDevices else { return }

        for device in devices {
            let id = device.device.id

            guard NotificationPreferences.isEnabled(for: id),
                let reading = device.reading,
                let newStatus = reading.status
            else {
                // Clear stored status so re-enabling doesn't fire a spurious transition
                previousStatuses.removeValue(forKey: id)
                continue
            }

            if let previous = previousStatuses[id], previous != newStatus {
                deliver(
                    deviceName: reading.name,
                    from: previous,
                    to: newStatus
                )
            }

            previousStatuses[id] = newStatus
        }
    }

    private func deliver(deviceName: String, from previous: AranetStatusColor, to current: AranetStatusColor) {
        let content = UNMutableNotificationContent()
        content.title = deviceName
        content.body = messageBody(from: previous, to: current)
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

    private func messageBody(from previous: AranetStatusColor, to current: AranetStatusColor) -> String {
        let base = "Just went from \(previous.displayName) to \(current.displayName)."
        switch current {
            case .red: return base + " Take action immediately."
            case .yellow: return base + " Consider ventilating."
            default: return base
        }
    }
}

// MARK: - AranetStatusColor display name

extension AranetStatusColor {
    var displayName: String {
        switch self {
            case .green: return "GREEN"
            case .yellow: return "YELLOW"
            case .red: return "RED"
            default: return "UNKNOWN"
        }
    }
}
