import AppKit
import AranetKit
import Foundation
import Testing

@testable import senor_particle

@Suite("SensorSymbol")
struct SensorSymbolTests {
    @Test(
        "Aranet4 symbols follow the air quality status",
        arguments: zip([AranetStatusColor.green, .yellow, .red, .error, nil], ["aqi.low", "aqi.medium", "aqi.high", "aqi", "aqi"])
    )
    func aranet4Symbols(status: AranetStatusColor?, expected: String) -> Void {
        #expect(SensorSymbol.systemName(for: .aranet4, status: status) == expected)
    }

    @Test(
        "Other device types have one symbol regardless of status",
        arguments: zip(
            [AranetDeviceType.aranet2, .aranetRadiation, .aranetRadon, .unknown],
            ["thermometer.medium", "atom", "humidity.fill", "dot.radiowaves.left.and.right"]
        )
    )
    func otherSymbols(type: AranetDeviceType, expected: String) -> Void {
        #expect(SensorSymbol.systemName(for: type, status: .red) == expected)
        #expect(SensorSymbol.systemName(for: type, status: nil) == expected)
    }

    @Test("Climate-only readings without a status count as green")
    func effectiveStatus() -> Void {
        #expect(SensorSymbol.effectiveStatus(from: nil) == nil)
        #expect(SensorSymbol.effectiveStatus(from: ReadingFixtures.aranet4(status: .red)) == .red)
        #expect(SensorSymbol.effectiveStatus(from: ReadingFixtures.aranet2()) == .green)
        #expect(SensorSymbol.effectiveStatus(from: AranetReading(humidity: 40)) == .green)
        #expect(SensorSymbol.effectiveStatus(from: AranetReading()) == nil)
    }

    @Test("Only the radiation symbol is shifted to look centered")
    func alignmentOffset() -> Void {
        #expect(SensorSymbol.alignmentOffset(for: .aranetRadiation) == NSSize(width: 0.75, height: 0))
        #expect(SensorSymbol.alignmentOffset(for: .aranet4) == .zero)
    }
}
