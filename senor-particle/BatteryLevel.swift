/// Maps a battery percentage to its SF Symbol and warning state.
nonisolated enum BatteryLevel {
    /// Below this percentage the battery icon turns red.
    static let criticalThreshold = 7

    /// Upper bounds (exclusive) of the empty, quarter, half, and three-quarter icons; each sits halfway between two icon levels.
    private static let emptyBelow = 13
    private static let quarterBelow = 38
    private static let halfBelow = 63
    private static let threeQuartersBelow = 88

    static func symbolName(for percentage: Int) -> String {
        if percentage < Self.emptyBelow {
            return "battery.0percent"
        }
        if percentage < Self.quarterBelow {
            return "battery.25percent"
        }
        if percentage < Self.halfBelow {
            return "battery.50percent"
        }
        if percentage < Self.threeQuartersBelow {
            return "battery.75percent"
        }
        return "battery.100percent"
    }

    static func isCritical(_ percentage: Int) -> Bool {
        return percentage < Self.criticalThreshold
    }
}
