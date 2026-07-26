import AppKit

enum MenuTrackingRefresh {
    /// Schedules work on the common run loop so it runs while an NSMenu is tracked.
    @MainActor static func perform(_ block: @escaping @MainActor @Sendable () -> Void) -> Void {
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated {
                block()
            }
        }
    }
}
