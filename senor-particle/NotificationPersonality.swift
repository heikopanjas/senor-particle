import Foundation

/// Carrot Weather-inspired notification tone levels.
enum NotificationPersonality: Int, CaseIterable {
    case professional = 0
    case friendly = 1
    case snarky = 2
    case overkill = 4

    var displayName: String {
        switch self {
            case .professional: return "Professional"
            case .friendly: return "Friendly"
            case .snarky: return "Snarky"
            case .overkill: return "Overkill"
        }
    }
}

enum NotificationPersonalityPreferences {
    private static let key = "notificationPersonality"

    static var current: NotificationPersonality {
        get {
            let raw = UserDefaults.standard.integer(forKey: key)
            return NotificationPersonality(rawValue: raw) ?? .professional
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
