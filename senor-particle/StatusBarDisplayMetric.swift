import AranetKit
import Foundation

/// One measurement shown in the status item, the status menu, the Devices tab, and notification text.
///
/// All user-facing value formatting lives in `valueString(for:unitSystem:)`, so every surface stays consistent.
nonisolated enum StatusBarDisplayMetric: String, CaseIterable {
    case co2
    case temperature
    case humidity
    case pressure
    case radiationRate
    case radiationTotal
    case radiationDuration
    case radonConcentration

    /// AranetKit has no millirem unit: 1 µSv equals 0.1 mrem.
    private static let milliremsPerMicrosievert = 0.1
    private static let secondsPerDay = 86_400.0

    var label: String {
        switch self {
            case .co2:
                return "CO\u{2082}"
            case .temperature:
                return "Temperature"
            case .humidity:
                return "Humidity"
            case .pressure:
                return "Pressure"
            case .radiationRate:
                return "Dose rate"
            case .radiationTotal:
                return "Total dose"
            case .radiationDuration:
                return "Duration"
            case .radonConcentration:
                return "Radon"
        }
    }

    /// Whether `reading` carries this measurement.
    func isAvailable(in reading: AranetReading) -> Bool {
        switch self {
            case .co2:
                return reading.co2 != nil
            case .temperature:
                return reading.temperature != nil
            case .humidity:
                return reading.humidity != nil
            case .pressure:
                return reading.pressure != nil
            case .radiationRate:
                return reading.radiationRate != nil
            case .radiationTotal:
                return reading.radiationTotal != nil
            case .radiationDuration:
                return reading.radiationDuration != nil
            case .radonConcentration:
                return reading.radonConcentration != nil
        }
    }

    /// The formatted value with its unit, or nil when `reading` does not carry this measurement.
    func valueString(for reading: AranetReading, unitSystem: DisplayUnitSystem) -> String? {
        switch self {
            case .co2:
                guard let co2 = reading.co2 else { return nil }
                return "\(co2) ppm"
            case .temperature:
                guard let temperature = reading.temperature else { return nil }
                return Self.temperatureString(temperature, unitSystem: unitSystem)
            case .humidity:
                guard let humidity = reading.humidity else { return nil }
                return "\(humidity)%"
            case .pressure:
                guard let pressure = reading.pressure else { return nil }
                return Self.pressureString(pressure, unitSystem: unitSystem)
            case .radiationRate:
                guard let radiationRate = reading.radiationRate else { return nil }
                let microsieverts = radiationRate.converted(to: .microsieverts).value
                switch unitSystem {
                    case .metric:
                        return String(format: "%.3f \u{00B5}Sv/h", microsieverts)
                    case .imperial:
                        return String(format: "%.3f mrem/h", microsieverts * Self.milliremsPerMicrosievert)
                }
            case .radiationTotal:
                guard let radiationTotal = reading.radiationTotal else { return nil }
                let microsieverts = radiationTotal.converted(to: .microsieverts).value
                switch unitSystem {
                    case .metric:
                        return String(format: "%.2f \u{00B5}Sv", microsieverts)
                    case .imperial:
                        return String(format: "%.2f mrem", microsieverts * Self.milliremsPerMicrosievert)
                }
            case .radiationDuration:
                guard let radiationDuration = reading.radiationDuration else { return nil }
                return String(format: "%.1f d", Double(radiationDuration) / Self.secondsPerDay)
            case .radonConcentration:
                guard let radonConcentration = reading.radonConcentration else { return nil }
                return Self.radonString(radonConcentration, unitSystem: unitSystem)
        }
    }

    /// The metrics `reading` carries, in declaration order.
    static func availableMetrics(for reading: AranetReading?) -> [StatusBarDisplayMetric] {
        guard let reading else { return [] }
        return Self.allCases.filter { $0.isAvailable(in: reading) }
    }

    /// The first available values, up to the status item's capacity; shown when nothing is pinned.
    static func defaultValueStrings(for reading: AranetReading, unitSystem: DisplayUnitSystem) -> [String] {
        let metrics = Self.availableMetrics(for: reading).prefix(StatusBarDisplaySelection.maximumMetrics)
        return metrics.compactMap { $0.valueString(for: reading, unitSystem: unitSystem) }
    }

    // MARK: - Unit conversion

    private static func temperatureString(_ temperature: Measurement<UnitTemperature>, unitSystem: DisplayUnitSystem) -> String {
        switch unitSystem {
            case .metric:
                return String(format: "%.1f \u{00B0}C", temperature.converted(to: .celsius).value)
            case .imperial:
                return String(format: "%.1f \u{00B0}F", temperature.converted(to: .fahrenheit).value)
        }
    }

    private static func pressureString(_ pressure: Measurement<UnitPressure>, unitSystem: DisplayUnitSystem) -> String {
        switch unitSystem {
            case .metric:
                return String(format: "%.1f hPa", pressure.converted(to: .hectopascals).value)
            case .imperial:
                return String(format: "%.2f inHg", pressure.converted(to: .inchesOfMercury).value)
        }
    }

    private static func radonString(_ concentration: Measurement<UnitRadioactivity>, unitSystem: DisplayUnitSystem) -> String {
        switch unitSystem {
            case .metric:
                return String(format: "%.0f Bq/m\u{00B3}", concentration.converted(to: .becquerelsPerCubicMeter).value)
            case .imperial:
                return String(format: "%.1f pCi/L", concentration.converted(to: .picocuriesPerLiter).value)
        }
    }
}
