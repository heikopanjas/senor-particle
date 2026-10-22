/// Whether sensor values are shown in metric or imperial units.
nonisolated enum DisplayUnitSystem: String, CaseIterable {
    case metric
    case imperial

    var displayName: String {
        switch self {
            case .metric:
                return "Metric"
            case .imperial:
                return "Imperial"
        }
    }
}
