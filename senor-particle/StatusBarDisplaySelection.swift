import AranetKit
import Foundation

/// The device and up to two ordered metrics pinned to the menu bar status item.
nonisolated struct StatusBarDisplaySelection: Equatable {
    static let maximumMetrics = 2

    let deviceId: UUID
    let metrics: [StatusBarDisplayMetric]

    /// Keeps the first occurrence of each metric, up to `maximumMetrics`; fails when no metric remains.
    init?(deviceId: UUID, metrics: [StatusBarDisplayMetric]) {
        var uniqueMetrics: [StatusBarDisplayMetric] = []
        for metric in metrics where uniqueMetrics.contains(metric) == false {
            uniqueMetrics.append(metric)
            if uniqueMetrics.count == Self.maximumMetrics {
                break
            }
        }

        guard uniqueMetrics.isEmpty == false else { return nil }
        self.deviceId = deviceId
        self.metrics = uniqueMetrics
    }

    /// Whether `metric` of `deviceId` is pinned.
    func contains(_ metric: StatusBarDisplayMetric, of deviceId: UUID) -> Bool {
        guard self.deviceId == deviceId else { return false }
        return self.metrics.contains(metric)
    }

    /// The pinned values `reading` carries, falling back to the default values when it carries none of them.
    func valueStrings(for reading: AranetReading, unitSystem: DisplayUnitSystem) -> [String] {
        let pinnedValues = self.metrics.compactMap { $0.valueString(for: reading, unitSystem: unitSystem) }
        guard pinnedValues.isEmpty == true else { return pinnedValues }
        return StatusBarDisplayMetric.defaultValueStrings(for: reading, unitSystem: unitSystem)
    }

    /// The selection after the user toggles `metric` of `deviceId`; a selection on another device is replaced.
    static func toggling(
        _ metric: StatusBarDisplayMetric,
        of deviceId: UUID,
        in selection: StatusBarDisplaySelection?
    ) -> StatusBarDisplaySelection? {
        guard let selection else { return StatusBarDisplaySelection(deviceId: deviceId, metrics: [metric]) }
        guard selection.deviceId == deviceId else { return StatusBarDisplaySelection(deviceId: deviceId, metrics: [metric]) }

        var metrics = selection.metrics
        if let index = metrics.firstIndex(of: metric) {
            metrics.remove(at: index)
        }
        else {
            metrics.append(metric)
        }
        return StatusBarDisplaySelection(deviceId: deviceId, metrics: metrics)
    }

    /// Whether the user may toggle `metric` of `deviceId`: a selection on another device, or a full one, blocks new metrics.
    static func canSelect(_ metric: StatusBarDisplayMetric, of deviceId: UUID, in selection: StatusBarDisplaySelection?) -> Bool {
        guard let selection else { return true }
        guard selection.deviceId == deviceId else { return false }
        if selection.metrics.contains(metric) == true {
            return true
        }
        return selection.metrics.count < Self.maximumMetrics
    }
}
