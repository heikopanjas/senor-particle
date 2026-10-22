import AppKit

enum MenuTrackingRefresh {
    /// Schedules work on the common run loop modes, so it runs while an `NSMenu` is tracked.
    ///
    /// Default-mode run loop sources do not fire during menu tracking, which would freeze an open status menu.
    static func perform(_ block: @escaping @MainActor @Sendable () -> Void) -> Void {
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated {
                block()
            }
        }
    }
}
