import AranetKit
import Foundation
import Testing

@testable import senor_particle

@Suite("StatusBarDisplaySelection")
struct StatusBarDisplaySelectionTests {
    private let deviceId = UUID()
    private let otherDeviceId = UUID()

    @Test("Metrics keep their first occurrence, up to two")
    func metricsAreUniqueAndCapped() throws -> Void {
        let selection = try #require(StatusBarDisplaySelection(deviceId: self.deviceId, metrics: [.co2, .co2, .temperature, .humidity]))

        #expect(selection.metrics == [.co2, .temperature])
    }

    @Test("A selection needs at least one metric")
    func emptySelectionFails() -> Void {
        #expect(StatusBarDisplaySelection(deviceId: self.deviceId, metrics: []) == nil)
    }

    @Test("Contains matches both the device and the metric")
    func containsChecksDevice() throws -> Void {
        let selection = try #require(StatusBarDisplaySelection(deviceId: self.deviceId, metrics: [.co2]))

        #expect(selection.contains(.co2, of: self.deviceId) == true)
        #expect(selection.contains(.temperature, of: self.deviceId) == false)
        #expect(selection.contains(.co2, of: self.otherDeviceId) == false)
    }

    @Test("Toggling adds, removes, and replaces a selection on another device")
    func toggling() -> Void {
        let first = StatusBarDisplaySelection.toggling(.co2, of: self.deviceId, in: nil)
        #expect(first?.metrics == [.co2])

        let second = StatusBarDisplaySelection.toggling(.humidity, of: self.deviceId, in: first)
        #expect(second?.metrics == [.co2, .humidity])

        let removed = StatusBarDisplaySelection.toggling(.co2, of: self.deviceId, in: second)
        #expect(removed?.metrics == [.humidity])

        let replaced = StatusBarDisplaySelection.toggling(.pressure, of: self.otherDeviceId, in: second)
        #expect(replaced == StatusBarDisplaySelection(deviceId: self.otherDeviceId, metrics: [.pressure]))

        #expect(StatusBarDisplaySelection.toggling(.humidity, of: self.deviceId, in: removed) == nil)
    }

    @Test("Only pinned metrics stay selectable once two are pinned, and other devices are blocked")
    func canSelect() -> Void {
        let one = StatusBarDisplaySelection(deviceId: self.deviceId, metrics: [.co2])
        let full = StatusBarDisplaySelection(deviceId: self.deviceId, metrics: [.co2, .humidity])

        #expect(StatusBarDisplaySelection.canSelect(.co2, of: self.deviceId, in: nil) == true)
        #expect(StatusBarDisplaySelection.canSelect(.temperature, of: self.deviceId, in: one) == true)
        #expect(StatusBarDisplaySelection.canSelect(.temperature, of: self.otherDeviceId, in: one) == false)
        #expect(StatusBarDisplaySelection.canSelect(.humidity, of: self.deviceId, in: full) == true)
        #expect(StatusBarDisplaySelection.canSelect(.temperature, of: self.deviceId, in: full) == false)
    }

    @Test("Pinned values the reading carries are shown in pinned order")
    func pinnedValuesInOrder() throws -> Void {
        let selection = try #require(StatusBarDisplaySelection(deviceId: self.deviceId, metrics: [.humidity, .co2]))

        #expect(selection.valueStrings(for: ReadingFixtures.aranet4(), unitSystem: .metric) == ["43%", "812 ppm"])
    }

    @Test("Pinned values the reading lacks are skipped")
    func missingPinnedValuesAreSkipped() throws -> Void {
        let selection = try #require(StatusBarDisplaySelection(deviceId: self.deviceId, metrics: [.radiationRate, .co2]))

        #expect(selection.valueStrings(for: ReadingFixtures.aranet4(), unitSystem: .metric) == ["812 ppm"])
    }

    @Test("A reading without any pinned value shows the default values")
    func noPinnedValueFallsBackToDefaults() throws -> Void {
        let selection = try #require(StatusBarDisplaySelection(deviceId: self.deviceId, metrics: [.radiationRate]))

        #expect(selection.valueStrings(for: ReadingFixtures.aranet4(), unitSystem: .metric) == ["812 ppm", "21.5 \u{00B0}C"])
    }
}
