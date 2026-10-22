import AranetKit
import Foundation

/// Remembers each device's last status color, so a notification fires once per transition.
nonisolated struct StatusTransitionTracker {
    private var previousStatuses: [UUID: AranetStatusColor] = [:]

    /// Records `status` for `deviceId` and returns the transition from the previously recorded status.
    ///
    /// The first status after notifications are enabled only sets the baseline. A disabled device or a reading without
    /// a status clears the baseline, so re-enabling never replays a transition that happened while notifications were off.
    mutating func evaluate(deviceId: UUID, status: AranetStatusColor?, enabled: Bool) -> StatusTransition? {
        guard enabled == true else {
            self.previousStatuses[deviceId] = nil
            return nil
        }
        guard let status else {
            self.previousStatuses[deviceId] = nil
            return nil
        }

        let previous = self.previousStatuses[deviceId]
        self.previousStatuses[deviceId] = status
        guard let previous else { return nil }
        guard previous != status else { return nil }
        return StatusTransition(from: previous, to: status)
    }
}
