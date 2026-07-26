import Foundation

extension Notification.Name {
    static let displayUnitSystemPreferenceDidChange = Notification.Name("displayUnitSystemPreferenceDidChange")
}

enum DisplayUnitSystem: String, CaseIterable {
    case metric
    case imperial

    var displayName: String {
        switch self {
            case .metric: return "Metric"
            case .imperial: return "Imperial"
        }
    }
}

enum DisplayUnitSystemPreferences {
    private static let key = "displayUnitSystem"

    static var current: DisplayUnitSystem {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                let unitSystem = DisplayUnitSystem(rawValue: raw)
            else { return systemDefault }

            return unitSystem
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NotificationCenter.default.post(name: .displayUnitSystemPreferenceDidChange, object: nil)
        }
    }

    static var systemDefault: DisplayUnitSystem {
        Locale.current.measurementSystem == .metric ? .metric : .imperial
    }
}
