import os

/// Unified-log categories of the app; all share the `com.panjas.senor-particle` subsystem.
///
/// Device names are logged with the default `private` privacy, so they stay out of persisted logs.
extension Logger {
    nonisolated private static let subsystem = "com.panjas.senor-particle"

    nonisolated static let app = Logger(subsystem: Self.subsystem, category: "app")
    nonisolated static let sensors = Logger(subsystem: Self.subsystem, category: "sensors")
    nonisolated static let notifications = Logger(subsystem: Self.subsystem, category: "notifications")
    nonisolated static let settings = Logger(subsystem: Self.subsystem, category: "settings")
}
