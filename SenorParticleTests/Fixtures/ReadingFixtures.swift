import AranetKit
import Foundation

/// Readings and devices for tests, with values whose formatted output is easy to state exactly.
nonisolated enum ReadingFixtures {
    static let aranet4Name = "Aranet4 1A2B3"

    static func aranet4(co2: UInt16 = 812, status: AranetStatusColor? = .green, interval: UInt16? = 300, ago: UInt16? = 42) -> AranetReading {
        return AranetReading(
            deviceType: .aranet4,
            name: Self.aranet4Name,
            temperature: Measurement(value: 21.5, unit: UnitTemperature.celsius),
            humidity: 43,
            co2: co2,
            pressure: Measurement(value: 1013.2, unit: UnitPressure.hectopascals),
            battery: 87,
            status: status,
            interval: interval,
            ago: ago
        )
    }

    static func aranet2() -> AranetReading {
        return AranetReading(
            deviceType: .aranet2,
            name: "Aranet2 4C5D6",
            temperature: Measurement(value: 19.5, unit: UnitTemperature.celsius),
            humidity: 55,
            battery: 64,
            interval: 600,
            ago: 17
        )
    }

    static func radiation(status: AranetStatusColor? = .green) -> AranetReading {
        return AranetReading(
            deviceType: .aranetRadiation,
            name: "Aranet Radiation 7E8F9",
            radiationRate: Measurement(value: 120, unit: UnitRadiationDose.nanosieverts),
            radiationTotal: Measurement(value: 1_234_567, unit: UnitRadiationDose.nanosieverts),
            radiationDuration: 90_061,
            battery: 71,
            status: status,
            interval: 60,
            ago: 5
        )
    }

    static func radon(status: AranetStatusColor? = .green) -> AranetReading {
        return AranetReading(
            deviceType: .aranetRadon,
            name: "Aranet Radon 0A1B2",
            temperature: Measurement(value: 18.0, unit: UnitTemperature.celsius),
            humidity: 50,
            pressure: Measurement(value: 1000.0, unit: UnitPressure.hectopascals),
            radonConcentration: Measurement(value: 148, unit: UnitRadioactivity.becquerelsPerCubicMeter),
            battery: 93,
            status: status,
            interval: 600,
            ago: 120
        )
    }

    /// A reading of an unknown device type that carries every measurement.
    static func everything() -> AranetReading {
        return AranetReading(
            temperature: Measurement(value: 21.5, unit: UnitTemperature.celsius),
            humidity: 43,
            co2: 812,
            pressure: Measurement(value: 1013.2, unit: UnitPressure.hectopascals),
            radiationRate: Measurement(value: 120, unit: UnitRadiationDose.nanosieverts),
            radiationTotal: Measurement(value: 1_234_567, unit: UnitRadiationDose.nanosieverts),
            radiationDuration: 90_061,
            radonConcentration: Measurement(value: 148, unit: UnitRadioactivity.becquerelsPerCubicMeter)
        )
    }

    static func device(named name: String) -> AranetDevice {
        return AranetDevice(id: UUID(), name: name)
    }
}
