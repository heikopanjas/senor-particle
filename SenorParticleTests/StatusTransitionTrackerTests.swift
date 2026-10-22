import AranetKit
import Foundation
import Testing

@testable import senor_particle

@Suite("StatusTransitionTracker")
struct StatusTransitionTrackerTests {
    private let deviceId = UUID()
    private let otherDeviceId = UUID()

    @Test("The first status sets the baseline, and only a change is a transition")
    func baselineThenChange() -> Void {
        var tracker = StatusTransitionTracker()

        #expect(tracker.evaluate(deviceId: self.deviceId, status: .green, enabled: true) == nil)
        #expect(tracker.evaluate(deviceId: self.deviceId, status: .green, enabled: true) == nil)
        #expect(tracker.evaluate(deviceId: self.deviceId, status: .yellow, enabled: true) == StatusTransition(from: .green, to: .yellow))
        #expect(tracker.evaluate(deviceId: self.deviceId, status: .red, enabled: true) == StatusTransition(from: .yellow, to: .red))
    }

    @Test("A change while notifications are off is never replayed")
    func disabledClearsBaseline() -> Void {
        var tracker = StatusTransitionTracker()
        _ = tracker.evaluate(deviceId: self.deviceId, status: .green, enabled: true)

        #expect(tracker.evaluate(deviceId: self.deviceId, status: .red, enabled: false) == nil)
        #expect(tracker.evaluate(deviceId: self.deviceId, status: .red, enabled: true) == nil)
        #expect(tracker.evaluate(deviceId: self.deviceId, status: .green, enabled: true) == StatusTransition(from: .red, to: .green))
    }

    @Test("A reading without a status clears the baseline")
    func missingStatusClearsBaseline() -> Void {
        var tracker = StatusTransitionTracker()
        _ = tracker.evaluate(deviceId: self.deviceId, status: .green, enabled: true)

        #expect(tracker.evaluate(deviceId: self.deviceId, status: nil, enabled: true) == nil)
        #expect(tracker.evaluate(deviceId: self.deviceId, status: .red, enabled: true) == nil)
    }

    @Test("Devices are tracked independently")
    func devicesAreIndependent() -> Void {
        var tracker = StatusTransitionTracker()
        _ = tracker.evaluate(deviceId: self.deviceId, status: .green, enabled: true)

        #expect(tracker.evaluate(deviceId: self.otherDeviceId, status: .red, enabled: true) == nil)
        #expect(tracker.evaluate(deviceId: self.deviceId, status: .red, enabled: true) == StatusTransition(from: .green, to: .red))
    }
}
