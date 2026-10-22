import AranetKit
import Foundation
import Testing

@testable import senor_particle

@Suite("UpdateCycleCalculator")
struct UpdateCycleCalculatorTests {
    private let anchor = Date(timeIntervalSince1970: 1_800_000_000)

    /// A reading that was 100 seconds old when it arrived, on a 400-second interval, degrading after three intervals.
    private var calculator: UpdateCycleCalculator {
        return UpdateCycleCalculator(anchor: self.anchor, startAgo: 100, interval: 400, degradedCycles: 3)
    }

    @Test(
        "The fraction counts from the reading's age and repeats every interval",
        arguments: [(0.0, 0.25), (100, 0.5), (299, 0.9975), (300, 0), (400, 0.25), (1099, 0.9975)]
    )
    func progress(secondsSinceAnchor: TimeInterval, expected: Double) -> Void {
        let state = self.calculator.state(at: self.anchor.addingTimeInterval(secondsSinceAnchor))

        #expect(state == .progressing(expected))
        #expect(state.fillFraction == expected)
    }

    @Test("Missing the degraded number of intervals is a degraded situation", arguments: [1100.0, 5000])
    func degraded(secondsSinceAnchor: TimeInterval) -> Void {
        let state = self.calculator.state(at: self.anchor.addingTimeInterval(secondsSinceAnchor))

        #expect(state == .degraded)
        #expect(state.fillFraction == 1)
    }

    @Test("A clock before the anchor shows an empty bar")
    func clockBeforeAnchor() -> Void {
        let calculator = UpdateCycleCalculator(anchor: self.anchor, startAgo: 0, interval: 400, degradedCycles: 3)

        #expect(calculator.state(at: self.anchor.addingTimeInterval(-100)) == .progressing(0))
    }

    @Test("A reading supplies the interval and age")
    func readingSuppliesIntervalAndAge() -> Void {
        let calculator = UpdateCycleCalculator(anchor: self.anchor, reading: ReadingFixtures.aranet4(interval: 300, ago: 42), degradedCycles: 2)

        #expect(calculator == UpdateCycleCalculator(anchor: self.anchor, startAgo: 42, interval: 300, degradedCycles: 2))
    }

    @Test("A reading without interval or age uses the default interval from zero")
    func readingWithoutIntervalOrAge() -> Void {
        let calculator = UpdateCycleCalculator(anchor: self.anchor, reading: ReadingFixtures.aranet4(interval: nil, ago: nil), degradedCycles: 3)

        #expect(calculator.startAgo == 0)
        #expect(calculator.interval == UpdateCycleCalculator.defaultInterval)
    }

    @Test("A zero interval counts as one second")
    func zeroInterval() -> Void {
        #expect(UpdateCycleCalculator.interval(for: ReadingFixtures.aranet4(interval: 0)) == 1)
    }
}
