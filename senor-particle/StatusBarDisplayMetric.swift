import AranetKit
import Foundation

extension Notification.Name {
    static let statusBarDisplayPreferenceDidChange = Notification.Name("statusBarDisplayPreferenceDidChange")
}

struct StatusBarDisplaySelection: Equatable {
    let deviceId: UUID
    let metrics: [StatusBarDisplayMetric]
}

enum StatusBarDisplayPreferences {
    private static let deviceIdKey = "statusBarDisplay.deviceId"
    private static let legacyMetricKey = "statusBarDisplay.metric"
    private static let metricsKey = "statusBarDisplay.metrics"
    private static let maximumMetrics = 2

    static var selection: StatusBarDisplaySelection? {
        guard let deviceIdString = UserDefaults.standard.string(forKey: deviceIdKey),
            let deviceId = UUID(uuidString: deviceIdString)
        else { return nil }

        let storedMetricStrings =
            UserDefaults.standard.stringArray(forKey: metricsKey)
            ?? UserDefaults.standard.string(forKey: legacyMetricKey).map { [$0] }
            ?? []

        var metrics: [StatusBarDisplayMetric] = []
        for metricString in storedMetricStrings {
            guard let metric = StatusBarDisplayMetric(rawValue: metricString),
                metrics.contains(metric) == false
            else { continue }
            metrics.append(metric)
            if metrics.count == maximumMetrics { break }
        }

        guard metrics.isEmpty == false else { return nil }
        return StatusBarDisplaySelection(deviceId: deviceId, metrics: metrics)
    }

    static func setSelection(deviceId: UUID, metric: StatusBarDisplayMetric) {
        setSelection(deviceId: deviceId, metrics: [metric])
    }

    static func setSelection(deviceId: UUID, metrics: [StatusBarDisplayMetric]) {
        var uniqueMetrics: [StatusBarDisplayMetric] = []
        for metric in metrics where uniqueMetrics.contains(metric) == false {
            uniqueMetrics.append(metric)
            if uniqueMetrics.count == maximumMetrics { break }
        }

        guard uniqueMetrics.isEmpty == false else {
            clearSelection()
            return
        }

        UserDefaults.standard.set(deviceId.uuidString, forKey: deviceIdKey)
        UserDefaults.standard.set(uniqueMetrics.map(\.rawValue), forKey: metricsKey)
        UserDefaults.standard.removeObject(forKey: legacyMetricKey)
        NotificationCenter.default.post(name: .statusBarDisplayPreferenceDidChange, object: nil)
    }

    static func toggleSelection(deviceId: UUID, metric: StatusBarDisplayMetric) {
        guard let selection, selection.deviceId == deviceId else {
            setSelection(deviceId: deviceId, metric: metric)
            return
        }

        var metrics = selection.metrics
        if let index = metrics.firstIndex(of: metric) {
            metrics.remove(at: index)
        }
        else if metrics.count < maximumMetrics {
            metrics.append(metric)
        }

        setSelection(deviceId: deviceId, metrics: metrics)
    }

    static func canSelect(deviceId: UUID, metric: StatusBarDisplayMetric) -> Bool {
        guard let selection else { return true }
        guard selection.deviceId == deviceId else { return false }
        return selection.metrics.contains(metric) || selection.metrics.count < maximumMetrics
    }

    static func isSelected(deviceId: UUID, metric: StatusBarDisplayMetric) -> Bool {
        guard let selection, selection.deviceId == deviceId else { return false }
        return selection.metrics.contains(metric)
    }

    static func valueStrings(for selection: StatusBarDisplaySelection, reading: AranetReading) -> [String]? {
        let values = selection.metrics.compactMap { $0.valueString(for: reading) }
        guard values.count == selection.metrics.count else { return nil }
        return values
    }

    static func title(for selection: StatusBarDisplaySelection, reading: AranetReading) -> String? {
        guard let value = valueStrings(for: selection, reading: reading)?.first else { return nil }
        return " \(value)"
    }

    static func defaultTitle(for reading: AranetReading) -> String? {
        guard let metric = StatusBarDisplayMetric.defaultMetric(for: reading),
            let value = metric.valueString(for: reading)
        else { return nil }
        return " \(value)"
    }

    static func maximumMetricCountReached(for deviceId: UUID) -> Bool {
        guard let selection, selection.deviceId == deviceId else { return false }
        return selection.metrics.count >= maximumMetrics
    }

    static func hasSelection(on deviceId: UUID) -> Bool {
        selection?.deviceId == deviceId
    }

    static func hasSelectionOnAnotherDevice(_ deviceId: UUID) -> Bool {
        guard let selection else { return false }
        return selection.deviceId != deviceId
    }

    static func postChangeNotification() {
        NotificationCenter.default.post(name: .statusBarDisplayPreferenceDidChange, object: nil)
    }

    static func clearSelection() {
        UserDefaults.standard.removeObject(forKey: deviceIdKey)
        UserDefaults.standard.removeObject(forKey: metricsKey)
        UserDefaults.standard.removeObject(forKey: legacyMetricKey)
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
