import AranetKit
import Foundation

extension Notification.Name {
    static let statusBarDisplayPreferenceDidChange = Notification.Name("statusBarDisplayPreferenceDidChange")
}

struct StatusBarDisplaySelection: Equatable {
    let deviceId: UUID
    let metric: StatusBarDisplayMetric
}

enum StatusBarDisplayPreferences {
    private static let deviceIdKey = "statusBarDisplay.deviceId"
    private static let metricKey = "statusBarDisplay.metric"

    static var selection: StatusBarDisplaySelection? {
        guard let deviceIdString = UserDefaults.standard.string(forKey: deviceIdKey),
            let deviceId = UUID(uuidString: deviceIdString),
            let metricString = UserDefaults.standard.string(forKey: metricKey),
            let metric = StatusBarDisplayMetric(rawValue: metricString)
        else { return nil }

        return StatusBarDisplaySelection(deviceId: deviceId, metric: metric)
    }

    static func setSelection(deviceId: UUID, metric: StatusBarDisplayMetric) {
        UserDefaults.standard.set(deviceId.uuidString, forKey: deviceIdKey)
        UserDefaults.standard.set(metric.rawValue, forKey: metricKey)
        NotificationCenter.default.post(name: .statusBarDisplayPreferenceDidChange, object: nil)
    }

    static func clearSelection() {
        UserDefaults.standard.removeObject(forKey: deviceIdKey)
        UserDefaults.standard.removeObject(forKey: metricKey)
        NotificationCenter.default.post(name: .statusBarDisplayPreferenceDidChange, object: nil)
    }
}

enum StatusBarDisplayMetric: String, CaseIterable {
    case co2
    case temperature
    case humidity
    case pressure
    case radiationRate
    case radiationTotal
    case radonConcentration

    var label: String {
        switch self {
            case .co2: return "CO\u{2082}"
            case .temperature: return "Temperature"
            case .humidity: return "Humidity"
            case .pressure: return "Pressure"
            case .radiationRate: return "Dose rate"
            case .radiationTotal: return "Total dose"
            case .radonConcentration: return "Radon"
        }
    }

    func valueString(for reading: AranetReading) -> String? {
        switch self {
            case .co2:
                guard let co2 = reading.co2 else { return nil }
                return "\(co2) ppm"
            case .temperature:
                guard let temperature = reading.temperature else { return nil }
                return String(format: "%.1f \u{00B0}C", temperature.value)
            case .humidity:
                guard let humidity = reading.humidity else { return nil }
                return "\(humidity)%"
            case .pressure:
                guard let pressure = reading.pressure else { return nil }
                return String(format: "%.1f hPa", pressure.value)
            case .radiationRate:
                guard let radiationRate = reading.radiationRate else { return nil }
                let uSv = radiationRate.converted(to: .microsieverts)
                return String(format: "%.3f \u{00B5}Sv/h", uSv.value)
            case .radiationTotal:
                guard let radiationTotal = reading.radiationTotal else { return nil }
                let uSv = radiationTotal.converted(to: .microsieverts)
                return String(format: "%.2f \u{00B5}Sv", uSv.value)
            case .radonConcentration:
                guard let radonConcentration = reading.radonConcentration else { return nil }
                return String(format: "%.0f Bq/m\u{00B3}", radonConcentration.value)
        }
    }

    func statusItemTitle(for reading: AranetReading) -> String? {
        guard let value = valueString(for: reading) else { return nil }
        return " \(value)"
    }

    static func availableMetrics(for reading: AranetReading?) -> [StatusBarDisplayMetric] {
        guard let reading else { return [] }
        return allCases.filter { $0.valueString(for: reading) != nil }
    }

    static func defaultMetric(for reading: AranetReading) -> StatusBarDisplayMetric? {
        let fallbackOrder: [StatusBarDisplayMetric] = [.co2, .radiationRate, .temperature]
        return fallbackOrder.first { $0.valueString(for: reading) != nil }
    }
}
