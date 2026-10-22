import Testing

@testable import senor_particle

@Suite("NotificationPersonality")
struct NotificationPersonalityTests {
    @Test("Stored raw values never change, and 3 stays unused")
    func rawValuesAreStable() -> Void {
        #expect(NotificationPersonality.allCases.map { $0.rawValue } == [0, 1, 2, 4])
        #expect(NotificationPersonality(rawValue: 3) == nil)
    }

    @Test("Every personality has its own display name")
    func displayNamesAreDistinct() -> Void {
        let names = Set(NotificationPersonality.allCases.map { $0.displayName })

        #expect(names.count == NotificationPersonality.allCases.count)
    }
}
