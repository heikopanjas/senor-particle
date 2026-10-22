import AranetKit
import Foundation
import Testing

@testable import senor_particle

@Suite("StatusNotificationCopy")
struct StatusNotificationCopyTests {
    /// Every color change that notifies; the six pairs map onto four kinds of transition.
    private static let notifyingTransitions = [
        StatusTransition(from: .green, to: .yellow),
        StatusTransition(from: .green, to: .red),
        StatusTransition(from: .yellow, to: .red),
        StatusTransition(from: .red, to: .yellow),
        StatusTransition(from: .yellow, to: .green),
        StatusTransition(from: .red, to: .green)
    ]

    /// One reading per copy table: CO₂, radiation, radon, and the generic table for climate-only devices.
    private static let readingPerCategory = [
        ReadingFixtures.aranet4(),
        ReadingFixtures.radiation(),
        ReadingFixtures.radon(),
        ReadingFixtures.aranet2()
    ]

    private static func content(
        for reading: AranetReading,
        transition: StatusTransition,
        personality: NotificationPersonality = .professional,
        unitSystem: DisplayUnitSystem = .metric
    ) -> StatusNotificationContent? {
        return StatusNotificationCopy.content(
            for: reading,
            title: "Office",
            transition: transition,
            personality: personality,
            unitSystem: unitSystem
        )
    }

    @Test("Every category, kind of transition, and personality has its own copy")
    func copyTablesAreComplete() -> Void {
        var bodies: Set<String> = []
        for reading in Self.readingPerCategory {
            for transition in Self.notifyingTransitions {
                for personality in NotificationPersonality.allCases {
                    let content = Self.content(for: reading, transition: transition, personality: personality)
                    #expect(content?.title == "Office")
                    if let body = content?.body {
                        bodies.insert(body)
                    }
                    else {
                        Issue.record("No copy for \(reading.deviceType.name), \(transition), \(personality)")
                    }
                }
            }
        }

        // 4 categories × 4 kinds of transition × 4 personalities.
        #expect(bodies.count == 64)
    }

    @Test(
        "Unchanged colors and the error color produce no notification",
        arguments: [
            StatusTransition(from: .green, to: .green),
            StatusTransition(from: .yellow, to: .yellow),
            StatusTransition(from: .red, to: .red),
            StatusTransition(from: .error, to: .error),
            StatusTransition(from: .error, to: .green),
            StatusTransition(from: .error, to: .red),
            StatusTransition(from: .green, to: .error),
            StatusTransition(from: .yellow, to: .error),
            StatusTransition(from: .red, to: .error)
        ]
    )
    func nonNotifyingTransitions(transition: StatusTransition) -> Void {
        #expect(Self.content(for: ReadingFixtures.aranet4(), transition: transition) == nil)
    }

    @Test("Worsening and improving to the same color use different copy")
    func directionMatters() -> Void {
        let worsening = Self.content(for: ReadingFixtures.aranet4(), transition: StatusTransition(from: .green, to: .yellow))
        let improving = Self.content(for: ReadingFixtures.aranet4(), transition: StatusTransition(from: .red, to: .yellow))

        #expect(worsening?.body == "CO\u{2082} is 812 ppm. Air quality is moderate. Consider ventilating.")
        #expect(improving?.body == "CO\u{2082} is 812 ppm. Air quality is improving but still moderate.")
    }

    @Test(
        "The body opens with the reading's key value in metric units",
        arguments: [
            (ReadingFixtures.aranet4(), "CO\u{2082} is 812 ppm. "),
            (ReadingFixtures.radiation(), "Radiation is 0.120 \u{00B5}Sv/h. "),
            (ReadingFixtures.radon(), "Radon is 148 Bq/m\u{00B3}. "),
            (ReadingFixtures.aranet2(), "Sensor reading updated. ")
        ]
    )
    func metricClause(reading: AranetReading, prefix: String) -> Void {
        let content = Self.content(for: reading, transition: StatusTransition(from: .green, to: .red), unitSystem: .metric)

        #expect(content?.body.hasPrefix(prefix) == true)
    }

    @Test(
        "The body opens with the reading's key value in imperial units",
        arguments: [
            (ReadingFixtures.radiation(), "Radiation is 0.012 mrem/h. "),
            (ReadingFixtures.radon(), "Radon is 4.0 pCi/L. ")
        ]
    )
    func imperialMetricClause(reading: AranetReading, prefix: String) -> Void {
        let content = Self.content(for: reading, transition: StatusTransition(from: .green, to: .red), unitSystem: .imperial)

        #expect(content?.body.hasPrefix(prefix) == true)
    }

    @Test(
        "Devices of unknown type use the copy of the measurement they carry",
        arguments: [
            (AranetReading(co2: 900), "CO\u{2082} is 900 ppm. Air quality is moderate. Consider ventilating."),
            (
                AranetReading(radiationRate: Measurement(value: 250, unit: UnitRadiationDose.nanosieverts)),
                "Radiation is 0.250 \u{00B5}Sv/h. Radiation levels are elevated. Monitor the situation."
            ),
            (
                AranetReading(radonConcentration: Measurement(value: 300, unit: UnitRadioactivity.becquerelsPerCubicMeter)),
                "Radon is 300 Bq/m\u{00B3}. Radon levels are elevated. Consider ventilation."
            ),
            (AranetReading(humidity: 40), "Sensor reading updated. Status is moderate. Check the sensor.")
        ]
    )
    func unknownDeviceTypes(reading: AranetReading, expected: String) -> Void {
        #expect(Self.content(for: reading, transition: StatusTransition(from: .green, to: .yellow))?.body == expected)
    }
}
