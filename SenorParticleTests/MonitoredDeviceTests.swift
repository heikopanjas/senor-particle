import Testing

@testable import senor_particle

@Suite("MonitoredDevice")
struct MonitoredDeviceTests {
    @Test("A new device waits for its first reading")
    func newDeviceDefaults() -> Void {
        let monitored = MonitoredDevice(device: ReadingFixtures.device(named: "Aranet4 Advertised"))

        #expect(monitored.reading == nil)
        #expect(monitored.lastUpdated == nil)
        #expect(monitored.updateSequence == 0)
        #expect(monitored.connectionState == .connecting)
    }

    @Test("The reported name prefers the reading over the advertised name")
    func reportedName() -> Void {
        var monitored = MonitoredDevice(device: ReadingFixtures.device(named: "Aranet4 Advertised"))
        #expect(monitored.reportedName == "Aranet4 Advertised")

        monitored.reading = ReadingFixtures.aranet4()
        #expect(monitored.reportedName == ReadingFixtures.aranet4Name)
    }
}
