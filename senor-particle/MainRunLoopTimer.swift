import Foundation

enum MainRunLoopTimer {
    /// Schedules a repeating timer on the main run loop in `.common` mode, so it keeps firing while a menu is tracked.
    ///
    /// The block runs directly on the main actor; no task is created per tick.
    static func scheduleRepeating(every interval: TimeInterval, _ block: @escaping @MainActor @Sendable () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated {
                block()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
