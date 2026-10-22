import AranetKit
import Foundation
import os

extension Notification.Name {
    /// Posted by `SensorManager` when a scan starts or ends.
    static let aranetScanStateDidChange = Notification.Name("aranetScanStateDidChange")
    /// Posted by `SensorManager` after a device's reading or connection state changed; `userInfo` names the device.
    static let sensorDevicesDidChange = Notification.Name("sensorDevicesDidChange")
}

/// Scans for devices, runs one monitoring loop per device, and publishes every change on the main actor.
///
/// Readings arrive through the AranetKit monitor streams this type iterates, not through `aranetReadingDidUpdate`,
/// so the compiler checks their isolation and no observer depends on notification delivery order. Everything else in
/// the app observes `sensorDevicesDidChange` and `aranetScanStateDidChange`.
final class SensorManager {
    typealias Sleep = @MainActor (TimeInterval) async throws -> Void
    typealias Clock = @MainActor () -> Date

    /// The `userInfo` key of `sensorDevicesDidChange`, holding the changed device's `UUID`.
    static let deviceIdUserInfoKey = "deviceId"
    /// Stream ends in a row, without a reading in between, after which a device's loop gives up.
    static let maximumRetries = 5
    /// Delay before the first reconnection attempt; it doubles with every further attempt.
    static let baseRetryDelay: TimeInterval = 5
    /// Delay before a failed scan is retried automatically.
    static let scanRetryDelay: TimeInterval = 30

    private static let connectionLostReason = "The connection was lost"

    /// A monitoring task and the token that identifies it, so a finished loop never removes its replacement.
    private struct MonitoringHandle {
        let token: UUID
        let task: Task<Void, Never>
    }

    private let client: any SensorClient
    private let preferences: PreferencesStore
    private let notificationCenter: NotificationCenter
    private let sleep: Sleep
    private let now: Clock
    private var monitoringHandles: [UUID: MonitoringHandle] = [:]
    private var scanTask: Task<Void, Never>?
    private var scanRetryTask: Task<Void, Never>?
    private var sortedDevicesCache: [MonitoredDevice]?

    private(set) var devices: [UUID: MonitoredDevice] = [:] {
        didSet {
            self.sortedDevicesCache = nil
        }
    }

    private(set) var isScanning = false {
        didSet {
            guard oldValue != self.isScanning else { return }
            self.notificationCenter.post(name: .aranetScanStateDidChange, object: self)
        }
    }

    /// Why the last scan failed, without a trailing period; nil after a successful scan.
    private(set) var scanError: String?

    init(
        client: any SensorClient = AranetClient(),
        preferences: PreferencesStore = .shared,
        notificationCenter: NotificationCenter = .default,
        sleep: @escaping Sleep = { try await Task.sleep(for: .seconds($0)) },
        now: @escaping Clock = { Date() }
    ) {
        self.client = client
        self.preferences = preferences
        self.notificationCenter = notificationCenter
        self.sleep = sleep
        self.now = now
    }

    /// Devices ordered by advertised name, then identifier; cached until `devices` changes.
    var sortedDevices: [MonitoredDevice] {
        if let cached = self.sortedDevicesCache {
            return cached
        }

        let sorted = self.devices.values.sorted { lhs, rhs in
            if lhs.device.name != rhs.device.name {
                return lhs.device.name < rhs.device.name
            }
            return lhs.device.id.uuidString < rhs.device.id.uuidString
        }
        self.sortedDevicesCache = sorted
        return sorted
    }

    /// Scans, then monitors every device that has no running loop. Does nothing while a scan is running.
    func rescan() -> Void {
        guard self.scanTask == nil else { return }

        self.scanRetryTask?.cancel()
        self.scanRetryTask = nil
        self.scanTask = Task { [weak self] in
            await self?.performScan()
        }
    }

    /// Cancels the scan, its pending retry, and every monitoring loop; AranetKit stops polling as each stream ends.
    func stopMonitoring() -> Void {
        self.scanTask?.cancel()
        self.scanRetryTask?.cancel()
        self.scanRetryTask = nil
        for handle in self.monitoringHandles.values {
            handle.task.cancel()
        }
        self.monitoringHandles.removeAll()
    }

    /// The delay before reconnection attempt `attempt`, counted from 1: 5, 10, 20, 40, then 80 seconds.
    static func retryDelay(forAttempt attempt: Int) -> TimeInterval {
        return Self.baseRetryDelay * pow(2.0, Double(attempt - 1))
    }

    // MARK: - Scanning

    private func performScan() async -> Void {
        self.isScanning = true
        defer {
            self.scanTask = nil
            self.isScanning = false
        }

        let found: [AranetDevice]
        do {
            found = try await self.client.scan(timeout: self.preferences.scanTimeout)
        }
        catch is CancellationError {
            return
        }
        catch {
            let message = error.localizedDescription
            Logger.sensors.error("Scan failed: \(message, privacy: .public)")
            self.scanError = Self.reason(from: error)
            self.scheduleScanRetry()
            return
        }

        self.scanError = nil
        for device in found where self.devices[device.id] == nil {
            self.devices[device.id] = MonitoredDevice(device: device)
        }
        self.startMonitoring()
    }

    private func scheduleScanRetry() -> Void {
        let delay = Self.scanRetryDelay
        self.scanRetryTask = Task { [weak self] in
            do {
                try await self?.sleep(delay)
            }
            catch {
                return
            }
            self?.scanRetryTask = nil
            self?.rescan()
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() -> Void {
        for monitored in self.sortedDevices where self.monitoringHandles[monitored.device.id] == nil {
            self.startMonitoring(monitored.device)
        }
    }

    private func startMonitoring(_ device: AranetDevice) -> Void {
        let token = UUID()
        let task = Task { [weak self] in
            await self?.monitor(device)
            self?.monitoringDidFinish(device.id, token: token)
        }
        self.monitoringHandles[device.id] = MonitoringHandle(token: token, task: task)
        self.setConnectionState(.connecting, for: device)
    }

    private func monitoringDidFinish(_ deviceId: UUID, token: UUID) -> Void {
        guard self.monitoringHandles[deviceId]?.token == token else { return }
        self.monitoringHandles[deviceId] = nil
    }

    /// Monitors one device until cancelled, reconnecting with exponential backoff whenever its stream ends.
    ///
    /// AranetKit finishes a monitor stream after its first failed read. Each stream end counts as one attempt and a
    /// reading resets the count. After `maximumRetries` attempts in a row the loop gives up and marks the device as
    /// failed; the next rescan starts a new loop.
    private func monitor(_ device: AranetDevice) async -> Void {
        let name = device.name
        let maximum = Self.maximumRetries
        var attempt = 0
        var lastFailure: String?

        while Task.isCancelled == false {
            for await result in self.client.monitor(from: device) {
                switch result {
                    case .success(let reading):
                        attempt = 0
                        lastFailure = nil
                        self.record(reading, for: device)
                    case .failure(let error):
                        let message = error.localizedDescription
                        Logger.sensors.error("Monitoring \(name) failed: \(message, privacy: .public)")
                        lastFailure = Self.reason(from: error)
                }
            }

            if Task.isCancelled == true {
                return
            }

            attempt += 1
            guard attempt <= maximum else {
                Logger.sensors.error("Giving up on \(name) after \(maximum) attempts")
                self.setConnectionState(.failed(lastFailure ?? Self.connectionLostReason), for: device)
                return
            }

            let seconds = Int(Self.retryDelay(forAttempt: attempt))
            Logger.sensors.info("Reconnecting to \(name) in \(seconds)s, attempt \(attempt) of \(maximum)")
            self.setConnectionState(.reconnecting(attempt: attempt, of: maximum), for: device)
            do {
                try await self.sleep(Self.retryDelay(forAttempt: attempt))
            }
            catch {
                return
            }
        }
    }

    private func record(_ reading: AranetReading, for device: AranetDevice) -> Void {
        var monitored = self.devices[device.id] ?? MonitoredDevice(device: device)
        monitored.reading = reading
        monitored.lastUpdated = self.now()
        monitored.updateSequence &+= 1
        monitored.connectionState = .connected
        self.devices[device.id] = monitored
        self.postDevicesDidChange(device.id)
    }

    private func setConnectionState(_ state: ConnectionState, for device: AranetDevice) -> Void {
        var monitored = self.devices[device.id] ?? MonitoredDevice(device: device)
        guard monitored.connectionState != state else { return }
        monitored.connectionState = state
        self.devices[device.id] = monitored
        self.postDevicesDidChange(device.id)
    }

    private func postDevicesDidChange(_ deviceId: UUID) -> Void {
        self.notificationCenter.post(name: .sensorDevicesDidChange, object: self, userInfo: [Self.deviceIdUserInfoKey: deviceId])
    }

    /// An error description without its trailing period, so it can be embedded in a sentence.
    private static func reason(from error: any Error) -> String {
        let description = error.localizedDescription
        guard description.hasSuffix(".") == true else { return description }
        return String(description.dropLast())
    }
}
