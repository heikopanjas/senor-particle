import AranetKit
import Foundation

extension Notification.Name {
    static let aranetScanStateDidChange = Notification.Name("aranetScanStateDidChange")
}

struct MonitoredDevice {
    let device: AranetDevice
    var reading: AranetReading?
    var lastUpdated: Date?
    var updateSequence: UInt = 0
}

class SensorManager {
    private let client = AranetClient()
    private var monitoringTasks: [UUID: Task<Void, Never>] = [:]

    private(set) var devices: [UUID: MonitoredDevice] = [:]
    private(set) var isScanning = false {
        didSet { NotificationCenter.default.post(name: .aranetScanStateDidChange, object: self) }
    }

    private let maxRetries = 5
    private let baseRetryDelay: TimeInterval = 5

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReadingDidUpdate),
            name: .aranetReadingDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func scan() async throws -> Void {
        self.isScanning = true
        defer { self.isScanning = false }

        let found = try await self.client.scan(timeout: ScanPreferences.timeout)
        for device in found where self.devices[device.id] == nil { self.devices[device.id] = MonitoredDevice(device: device) }
    }

    func rescan() -> Void {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.scan()
                self.startMonitoring()
            }
            catch { NSLog("[SensorManager] Rescan failed: %@", error.localizedDescription) }
        }
    }

    func startMonitoring() -> Void {
        for (id, monitored) in self.devices where self.monitoringTasks[id] == nil {
            self.monitoringTasks[id] = Task { @MainActor [weak self] in
                await self?.monitorWithRetry(id: id, device: monitored.device)
            }
        }
    }

    func stopMonitoring() -> Void {
        for (_, task) in self.monitoringTasks { task.cancel() }
        self.monitoringTasks.removeAll()
    }

    var sortedDevices: [MonitoredDevice] { return self.devices.values.sorted { $0.device.name < $1.device.name } }

    // MARK: - Private

    @objc private func handleReadingDidUpdate(_ notification: Notification) -> Void {
        guard let device = notification.userInfo?[AranetNotificationKey.device] as? AranetDevice,
            let reading = notification.userInfo?[AranetNotificationKey.reading] as? AranetReading
        else { return }

        let receivedAt = notification.userInfo?[AranetNotificationKey.receivedAt] as? Date ?? Date()

        if self.devices[device.id] == nil {
            self.devices[device.id] = MonitoredDevice(device: device)
        }

        self.devices[device.id]?.reading = reading
        self.devices[device.id]?.lastUpdated = receivedAt
        self.devices[device.id]?.updateSequence &+= 1
    }

    private func monitorWithRetry(id: UUID, device: AranetDevice) async -> Void {
        var retryCount = 0

        while Task.isCancelled == false {
            let stream = self.client.monitor(from: device)

            for await result in stream {
                if Task.isCancelled == true { return }

                switch result {
                    case .success: break
                    case .failure: break
                }
            }

            if Task.isCancelled == true { return }

            retryCount += 1
            if retryCount > self.maxRetries {
                NSLog("[SensorManager] Giving up on %@ after %d retries", device.name, self.maxRetries)
                return
            }

            let delay = self.baseRetryDelay * pow(2.0, Double(retryCount - 1))
            NSLog(
                "[SensorManager] Reconnecting to %@ in %.0fs (attempt %d/%d)", device.name, delay, retryCount,
                self.maxRetries)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
