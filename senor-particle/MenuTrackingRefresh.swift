import AppKit

enum MenuTrackingRefresh {
    /// Schedules work on the common run loop so it runs while an NSMenu is tracked.
    static func perform(_ block: @escaping () -> Void) {
        RunLoop.main.perform(inModes: [.common], block: block)
    }
}
