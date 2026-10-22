import AranetKit
import Foundation
import Testing

@testable import senor_particle

@Suite("SensorManager")
struct SensorManagerTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private let temporary: TemporaryDefaults
    private let center = NotificationCenter()
    private let client = FakeSensorClient()
    private let gate = SleepGate()
    private let manager: SensorManager

    init() throws {
        self.temporary = try TemporaryDefaults()
        let preferences = PreferencesStore(defaults: self.temporary.defaults, notificationCenter: self.center)
        let gate = self.gate
        self.manager = SensorManager(
            client: self.client,
            preferences: preferences,
            notificationCenter: self.center,
            sleep: { try await gate.sleep($0) },
            now: { SensorManagerTests.now }
        )
    }

    // MARK: - Scanning

    @Test("A scan uses the stored timeout and announces its start and end")
    func scanAnnouncesState() async -> Void {
        let recorder = NotificationRecorder(name: .aranetScanStateDidChange, center: self.center)

        self.manager.rescan()
        await settle("the scan to start") { self.client.pendingScans == 1 }
        #expect(self.manager.isScanning == true)
        #expect(self.client.scanTimeouts == [PreferencesStore.defaultScanTimeout])

        self.client.finishScans(returning: [])
        await settle("the scan to end") { self.manager.isScanning == false }
        #expect(recorder.notifications.count == 2)
        #expect(self.manager.scanError == nil)
    }

    @Test("Rescan does nothing while a scan is running")
    func rescanIsIgnoredWhileScanning() async -> Void {
        self.manager.rescan()
        self.manager.rescan()
        await settle("the scan to start") { self.client.pendingScans == 1 }
        self.manager.rescan()
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(self.client.scanTimeouts.count == 1)
        #expect(self.client.pendingScans == 1)

        self.client.finishScans(returning: [])
        await settle("the scan to end") { self.manager.isScanning == false }
    }

    @Test("A failed scan shows its reason without the period and retries after 30 seconds")
    func failedScanRetries() async -> Void {
        self.manager.rescan()
        await settle("the scan to start") { self.client.pendingScans == 1 }

        self.client.failScans(with: .bluetoothUnauthorized)
        await settle("the scan retry to wait") { self.gate.waiting == 1 }
        #expect(self.manager.isScanning == false)
        #expect(self.manager.scanError == "Bluetooth access is not authorized. Please grant Bluetooth permissions in System Settings")
        #expect(self.gate.requestedDelays == [SensorManager.scanRetryDelay])

        self.gate.release()
        await settle("the retried scan to start") { self.client.pendingScans == 1 }
        self.client.finishScans(returning: [])
        await settle("the retried scan to end") { self.manager.isScanning == false }
        #expect(self.manager.scanError == nil)
    }

    @Test("A rescan adds new devices and keeps the loops of known ones")
    func rescanMergesDevices() async -> Void {
        let first = ReadingFixtures.device(named: "Aranet4 Alpha")
        let second = ReadingFixtures.device(named: "Aranet4 Bravo")

        await self.scan(returning: [first])
        await settle("the first device's stream") { self.client.monitorCallCount(for: first) == 1 }
        await self.scan(returning: [first, second])
        await settle("the second device's stream") { self.client.monitorCallCount(for: second) == 1 }

        #expect(self.client.monitorCallCount(for: first) == 1)
        #expect(Set(self.manager.devices.keys) == [first.id, second.id])
        #expect(self.manager.devices[second.id]?.connectionState == .connecting)

        self.manager.stopMonitoring()
    }

    @Test("Devices sort by advertised name, then by identifier")
    func sortedDevices() async -> Void {
        let ids = [UUID(), UUID()].sorted { $0.uuidString < $1.uuidString }
        let alpha = ReadingFixtures.device(named: "Aranet4 Alpha")
        let lowBravo = AranetDevice(id: ids[0], name: "Aranet4 Bravo")
        let highBravo = AranetDevice(id: ids[1], name: "Aranet4 Bravo")

        await self.scan(returning: [highBravo, alpha, lowBravo])

        #expect(self.manager.sortedDevices.map { $0.device.id } == [alpha.id, lowBravo.id, highBravo.id])

        self.manager.stopMonitoring()
    }

    // MARK: - Monitoring

    @Test("A reading updates the device and announces it")
    func readingUpdatesDevice() async throws -> Void {
        let recorder = NotificationRecorder(name: .sensorDevicesDidChange, center: self.center)
        let device = ReadingFixtures.device(named: "Aranet4 Alpha")
        let reading = ReadingFixtures.aranet4()

        await self.scan(returning: [device])
        await settle("the monitor stream") { self.client.monitorCallCount(for: device) == 1 }
        self.client.yield(.success(reading), to: device)
        await settle("the reading") { self.manager.devices[device.id]?.reading == reading }

        let monitored = try #require(self.manager.devices[device.id])
        #expect(monitored.lastUpdated == Self.now)
        #expect(monitored.updateSequence == 1)
        #expect(monitored.connectionState == .connected)
        // A new device already reads as connecting, so only the reading is announced.
        let announcedIds = recorder.userInfoValues(forKey: SensorManager.deviceIdUserInfoKey, as: UUID.self)
        #expect(announcedIds == [device.id])

        self.manager.stopMonitoring()
    }

    @Test("A stream that keeps ending backs off 5, 10, 20, 40, and 80 seconds, then gives up with the last failure")
    func backoffThenGiveUp() async -> Void {
        let device = ReadingFixtures.device(named: "Aranet4 Alpha")
        let maximum = SensorManager.maximumRetries

        await self.scan(returning: [device])
        await settle("the first monitor stream") { self.client.monitorCallCount(for: device) == 1 }

        for attempt in 1 ... maximum {
            self.client.finishLatestStream(for: device)
            await settle("reconnection attempt \(attempt)") { self.gate.waiting == 1 }
            #expect(self.manager.devices[device.id]?.connectionState == .reconnecting(attempt: attempt, of: maximum))
            self.gate.release()
            await settle("monitor stream \(attempt + 1)") { self.client.monitorCallCount(for: device) == attempt + 1 }
        }

        self.client.yield(.failure(AranetError.readFailed), to: device)
        self.client.finishLatestStream(for: device)
        await settle("the loop to give up") { self.manager.devices[device.id]?.connectionState == .failed("Failed to read characteristic") }

        #expect(self.gate.requestedDelays == [5, 10, 20, 40, 80])
        #expect(self.gate.waiting == 0)

        await self.scan(returning: [device])
        await settle("a new monitor stream after rescanning") { self.client.monitorCallCount(for: device) == maximum + 2 }
        #expect(self.manager.devices[device.id]?.connectionState == .connecting)

        self.manager.stopMonitoring()
    }

    @Test("A loop that gives up without a failure reports the lost connection")
    func giveUpWithoutFailure() async -> Void {
        let device = ReadingFixtures.device(named: "Aranet4 Alpha")

        await self.scan(returning: [device])
        for attempt in 1 ... SensorManager.maximumRetries {
            await settle("monitor stream \(attempt)") { self.client.monitorCallCount(for: device) == attempt }
            self.client.finishLatestStream(for: device)
            await settle("reconnection attempt \(attempt)") { self.gate.waiting == 1 }
            self.gate.release()
        }
        await settle("the last monitor stream") { self.client.monitorCallCount(for: device) == SensorManager.maximumRetries + 1 }
        self.client.finishLatestStream(for: device)

        await settle("the loop to give up") { self.manager.devices[device.id]?.connectionState == .failed("The connection was lost") }
    }

    @Test("A reading resets the reconnection count")
    func readingResetsAttempts() async -> Void {
        let device = ReadingFixtures.device(named: "Aranet4 Alpha")

        await self.scan(returning: [device])
        await settle("the first monitor stream") { self.client.monitorCallCount(for: device) == 1 }
        self.client.finishLatestStream(for: device)
        await settle("the first reconnection") { self.gate.waiting == 1 }
        self.gate.release()
        await settle("the second monitor stream") { self.client.monitorCallCount(for: device) == 2 }

        self.client.yield(.success(ReadingFixtures.aranet4()), to: device)
        await settle("the reading") { self.manager.devices[device.id]?.connectionState == .connected }
        self.client.finishLatestStream(for: device)
        await settle("the second reconnection") { self.gate.waiting == 1 }

        #expect(self.gate.requestedDelays == [5, 5])
        #expect(self.manager.devices[device.id]?.connectionState == .reconnecting(attempt: 1, of: SensorManager.maximumRetries))

        self.manager.stopMonitoring()
        await settle("the sleeping loop to stop") { self.gate.waiting == 0 }
    }

    @Test("Stopping ends every monitor stream, and a rescan starts them again")
    func stopMonitoringEndsStreams() async -> Void {
        let first = ReadingFixtures.device(named: "Aranet4 Alpha")
        let second = ReadingFixtures.device(named: "Aranet4 Bravo")

        await self.scan(returning: [first, second])
        await settle("both monitor streams") { self.client.monitorCallCount(for: first) == 1 && self.client.monitorCallCount(for: second) == 1 }

        self.manager.stopMonitoring()
        await settle("both streams to end") { self.client.terminations == 2 }
        #expect(self.gate.requestedDelays.isEmpty == true)

        await self.scan(returning: [first, second])
        await settle("both streams to restart") { self.client.monitorCallCount(for: first) == 2 && self.client.monitorCallCount(for: second) == 2 }

        self.manager.stopMonitoring()
        await settle("the restarted streams to end") { self.client.terminations == 4 }
    }

    @Test("Reconnection delays double from 5 seconds", arguments: zip(1 ... 5, [5.0, 10, 20, 40, 80]))
    func retryDelay(attempt: Int, expected: TimeInterval) -> Void {
        #expect(SensorManager.retryDelay(forAttempt: attempt) == expected)
    }

    // MARK: - Helpers

    /// Runs one scan that finds `devices` and waits until it has ended.
    private func scan(returning devices: [AranetDevice]) async -> Void {
        self.manager.rescan()
        await settle("the scan to start") { self.client.pendingScans == 1 }
        self.client.finishScans(returning: devices)
        await settle("the scan to end") { self.manager.isScanning == false }
    }
}
