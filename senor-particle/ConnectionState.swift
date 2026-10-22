/// How the monitoring loop of one device is doing, shown in the status menu and the Devices tab.
nonisolated enum ConnectionState: Equatable {
    /// Waiting for the first reading since monitoring started.
    case connecting
    /// The latest stream delivered a reading.
    case connected
    /// The stream ended and the loop waits before reconnection attempt `attempt` of `maximum`.
    case reconnecting(attempt: Int, of: Int)
    /// The loop gave up; the description of the last failure, without a trailing period, is attached.
    case failed(String)

    /// A sentence for the device row in the status menu, or nil when the state needs no explanation.
    var menuText: String? {
        switch self {
            case .connecting:
                return nil
            case .connected:
                return nil
            case .reconnecting(let attempt, let maximum):
                return "Reconnecting, attempt \(attempt) of \(maximum)\u{2026}"
            case .failed(let reason):
                return "Monitoring stopped: \(reason). Choose Rescan to try again."
        }
    }

    /// A short label for the Devices tab status column, or nil when the column shows the reading age instead.
    var columnText: String? {
        switch self {
            case .connecting:
                return nil
            case .connected:
                return nil
            case .reconnecting(let attempt, let maximum):
                return "Reconnecting (\(attempt)/\(maximum))"
            case .failed:
                return "Stopped"
        }
    }
}
