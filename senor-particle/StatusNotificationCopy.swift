import AranetKit
import Foundation

enum StatusNotificationCopy {
    static func content(
        for reading: AranetReading,
        deviceId: UUID,
        from previous: AranetStatusColor,
        to current: AranetStatusColor,
        personality: NotificationPersonality = NotificationPersonalityPreferences.current
    ) -> (title: String, body: String)? {
        guard let transition = StatusTransitionKind(from: previous, to: current) else { return nil }

        let title = DeviceNamePreferences.name(for: deviceId) ?? reading.name
        let metric = metricClause(for: reading)
        guard
            let tail = copy(
                for: deviceCategory(for: reading),
                transition: transition,
                personality: personality
            )
        else { return nil }

        return (title, "\(metric) \(tail)")
    }

    // MARK: - Types

    private enum DeviceCategory {
        case co2
        case radiation
        case radon
        case generic
    }

    private enum StatusTransitionKind {
        case worseningToYellow
        case worseningToRed
        case improvingToYellow
        case improvingToGreen

        init?(from previous: AranetStatusColor, to current: AranetStatusColor) {
            switch (previous, current) {
                case (.green, .yellow): self = .worseningToYellow
                case (.yellow, .red), (.green, .red): self = .worseningToRed
                case (.red, .yellow): self = .improvingToYellow
                case (.yellow, .green), (.red, .green): self = .improvingToGreen
                default: return nil
            }
        }
    }

    // MARK: - Metric

    private static func deviceCategory(for reading: AranetReading) -> DeviceCategory {
        switch reading.deviceType {
            case .aranet4: return .co2
            case .aranetRadiation: return .radiation
            case .aranetRadon: return .radon
            default:
                if reading.co2 != nil { return .co2 }
                if reading.radiationRate != nil { return .radiation }
                if reading.radonConcentration != nil { return .radon }
                return .generic
        }
    }

    private static func metricClause(for reading: AranetReading) -> String {
        if let value = StatusBarDisplayMetric.co2.valueString(for: reading) {
            return "CO\u{2082} is \(value)."
        }
        if let value = StatusBarDisplayMetric.radiationRate.valueString(for: reading) {
            return "Radiation is \(value)."
        }
        if let value = StatusBarDisplayMetric.radonConcentration.valueString(for: reading) {
            return "Radon is \(value)."
        }
        return "Sensor reading updated."
    }

    // MARK: - Copy tables

    private static func copy(
        for category: DeviceCategory,
        transition: StatusTransitionKind,
        personality: NotificationPersonality
    ) -> String? {
        copyTable[category]?[transition]?[personality]
    }

    private static let copyTable: [DeviceCategory: [StatusTransitionKind: [NotificationPersonality: String]]] = [
        .co2: co2Copy,
        .radiation: radiationCopy,
        .radon: radonCopy,
        .generic: genericCopy
    ]

    private static let co2Copy: [StatusTransitionKind: [NotificationPersonality: String]] = [
        .worseningToYellow: [
            .professional: "Air quality is moderate. Consider ventilating.",
            .friendly: "The air is getting a bit stuffy. Maybe crack a window?",
            .snarky: "Air quality is slipping. Your lungs noticed before you did.",
            .overkill: "Air quality is now artisanal stale. Open a window before you become part of the ambiance."
        ],
        .worseningToRed: [
            .professional: "Air quality is poor. Ventilate the room.",
            .friendly: "The air could use some help — maybe open a window?",
            .snarky: "This air quality is a choice. Open a window.",
            .overkill: "Your air is now 70% human exhalation and 30% regret. Open a window."
        ],
        .improvingToYellow: [
            .professional: "Air quality is improving but still moderate.",
            .friendly: "Getting better! Keep ventilating a little longer.",
            .snarky: "The air is recovering. Do not declare victory and shut the window yet.",
            .overkill: "The air is slightly less oppressive. Progress, I suppose."
        ],
        .improvingToGreen: [
            .professional: "Air quality is good again.",
            .friendly: "Fresh air achieved. Breathe easy.",
            .snarky: "Air quality is good again. I will try not to look disappointed.",
            .overkill: "Air quality restored to mostly not your own breath. Celebrate responsibly."
        ]
    ]

    private static let radiationCopy: [StatusTransitionKind: [NotificationPersonality: String]] = [
        .worseningToYellow: [
            .professional: "Radiation levels are elevated. Monitor the situation.",
            .friendly: "Radiation is a bit higher than usual. Nothing to panic about yet.",
            .snarky: "Radiation is elevated. The background hum just got louder.",
            .overkill: "Radiation is up. Your glow-in-the-dark phase begins now. Limit exposure."
        ],
        .worseningToRed: [
            .professional: "Radiation levels are high. Limit exposure.",
            .friendly: "Radiation is high. Please keep your distance and stay safe.",
            .snarky: "Radiation is high. This is not the kind of glow-up you want.",
            .overkill: "Radiation is high enough to make a Geiger counter nervous. Limit exposure immediately."
        ],
        .improvingToYellow: [
            .professional: "Radiation levels are decreasing but still elevated.",
            .friendly: "Levels are coming down. Still elevated — stay cautious.",
            .snarky: "Radiation is easing off. Do not get comfortable yet.",
            .overkill: "Radiation is down from alarming to merely unsettling. Keep monitoring."
        ],
        .improvingToGreen: [
            .professional: "Radiation levels are back to normal.",
            .friendly: "Radiation is back to normal. All clear.",
            .snarky: "Radiation is normal again. The universe has returned to its regularly scheduled background noise.",
            .overkill: "Radiation is back to boring background levels. Try not to miss the excitement."
        ]
    ]

    private static let radonCopy: [StatusTransitionKind: [NotificationPersonality: String]] = [
        .worseningToYellow: [
            .professional: "Radon levels are elevated. Consider ventilation.",
            .friendly: "Radon is a bit high. Fresh air would help.",
            .snarky: "Radon is elevated. Your basement may be feeling ambitious.",
            .overkill: "Radon is elevated. Even the rocks under your house are getting chatty. Ventilate."
        ],
        .worseningToRed: [
            .professional: "Radon levels are high. Ventilate and test the space.",
            .friendly: "Radon is high. Please ventilate and check the area.",
            .snarky: "Radon is high. This is a basement problem, not a you problem — fix the air.",
            .overkill: "Radon is high enough to make soil jealous. Ventilate immediately."
        ],
        .improvingToYellow: [
            .professional: "Radon levels are improving but still elevated.",
            .friendly: "Radon is coming down. Keep ventilating a while longer.",
            .snarky: "Radon is easing. Do not close every window in celebration.",
            .overkill: "Radon is less terrifying but still not a spa day. Keep the air moving."
        ],
        .improvingToGreen: [
            .professional: "Radon levels are back to normal.",
            .friendly: "Radon is back to normal. Nice work.",
            .snarky: "Radon is normal again. The ground has calmed down.",
            .overkill: "Radon is back to politely invisible. Enjoy your non-radioactive air."
        ]
    ]

    private static let genericCopy: [StatusTransitionKind: [NotificationPersonality: String]] = [
        .worseningToYellow: [
            .professional: "Status is moderate. Check the sensor.",
            .friendly: "Things are a bit off. Worth keeping an eye on.",
            .snarky: "Status slipped to moderate. The sensor noticed before you did.",
            .overkill: "Status is moderate, which is sensor-speak for not great."
        ],
        .worseningToRed: [
            .professional: "Status is poor. Take action.",
            .friendly: "Status is poor. Please check the sensor readings.",
            .snarky: "Status is poor. This is your cue to do something.",
            .overkill: "Status is poor. The sensor is not being dramatic for fun."
        ],
        .improvingToYellow: [
            .professional: "Status is improving but still moderate.",
            .friendly: "Getting better, but not all clear yet.",
            .snarky: "Status is improving. Do not get cocky.",
            .overkill: "Status is less bad. A triumph of modest proportions."
        ],
        .improvingToGreen: [
            .professional: "Status is good again.",
            .friendly: "All clear. Readings look good.",
            .snarky: "Status is good again. Crisis averted, for now.",
            .overkill: "Status is good. The sensor returns to its usual silent judgment."
        ]
    ]
}
