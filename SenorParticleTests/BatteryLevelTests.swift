import Testing

@testable import senor_particle

@Suite("BatteryLevel")
struct BatteryLevelTests {
    @Test(
        "Each icon covers the percentages closest to its level",
        arguments: zip(
            [0, 12, 13, 37, 38, 62, 63, 87, 88, 100],
            [
                "battery.0percent",
                "battery.0percent",
                "battery.25percent",
                "battery.25percent",
                "battery.50percent",
                "battery.50percent",
                "battery.75percent",
                "battery.75percent",
                "battery.100percent",
                "battery.100percent"
            ]
        )
    )
    func symbolName(percentage: Int, expected: String) -> Void {
        #expect(BatteryLevel.symbolName(for: percentage) == expected)
    }

    @Test("The battery is critical below the threshold", arguments: zip([0, 6, 7, 100], [true, true, false, false]))
    func isCritical(percentage: Int, expected: Bool) -> Void {
        #expect(BatteryLevel.isCritical(percentage) == expected)
    }
}
