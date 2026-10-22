import AranetKit
import Foundation

/// Where a device is within its update interval, and whether it has missed too many updates.
///
/// The position is `startAgo` (the reading's age when it arrived) plus the time since `anchor` (when it arrived),
/// repeating every `interval`. From `interval × degradedCycles` on, the situation is degraded.
nonisolated struct UpdateCycleCalculator: Equatable {
    /// The interval assumed when a reading does not report one.
    static let defaultInterval: TimeInterval = 300

    enum State: Equatable {
        /// The fraction of the current interval that has passed, from 0 up to but excluding 1.
        case progressing(Double)
        /// The device missed `degradedCycles` intervals in a row.
        case degraded

        /// The width of the progress bar fill, from 0 to 1.
        var fillFraction: Double {
            switch self {
                case .progressing(let fraction):
                    return fraction
                case .degraded:
                    return 1
            }
        }
    }

    let anchor: Date
    let startAgo: TimeInterval
    let interval: TimeInterval
    let degradedCycles: Int

    func state(at now: Date) -> State {
        let elapsed = max(self.startAgo + now.timeIntervalSince(self.anchor), 0)
        if elapsed >= self.interval * Double(self.degradedCycles) {
            return .degraded
        }
        return .progressing(elapsed.truncatingRemainder(dividingBy: self.interval) / self.interval)
    }
}

extension UpdateCycleCalculator {
    /// Starts a cycle for `reading`, which arrived at `anchor`.
    init(anchor: Date, reading: AranetReading, degradedCycles: Int) {
        self.init(
            anchor: anchor,
            startAgo: TimeInterval(reading.ago ?? 0),
            interval: Self.interval(for: reading),
            degradedCycles: degradedCycles
        )
    }

    /// The reading's update interval, at least one second, or `defaultInterval` when it reports none.
    static func interval(for reading: AranetReading) -> TimeInterval {
        guard let interval = reading.interval else { return Self.defaultInterval }
        return TimeInterval(max(interval, 1))
    }
}
