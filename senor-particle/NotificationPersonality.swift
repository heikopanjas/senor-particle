/// Carrot Weather-inspired notification tone levels.
///
/// Raw values are persisted. Raw value 3 is unused, and any unknown stored value reads as `professional`;
/// never renumber the cases, that would change the stored preference of existing users.
nonisolated enum NotificationPersonality: Int, CaseIterable {
    case professional = 0
    case friendly = 1
    case snarky = 2
    case overkill = 4

    var displayName: String {
        switch self {
            case .professional:
                return "Professional"
            case .friendly:
                return "Friendly"
            case .snarky:
                return "Snarky"
            case .overkill:
                return "Overkill"
        }
    }
}
