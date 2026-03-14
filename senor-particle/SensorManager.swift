import AranetKit
import Foundation

struct MonitoredDevice {
    let device: AranetDevice
    var reading: AranetReading?
    var lastUpdated: Date?
}

class SensorManager {
    private let client = AranetClient()
    private var monitoringTasks: [UUID: Task<Void, Never>] = [:]

    private(set) var devices: [UUID: MonitoredDevice] = [:]
    private(set) var isScanning = false

    private let maxRetries = 5
    private let baseRetryDelay: TimeInterval = 5

    var onUpdate: (() -> Void)?

    func scan() async throws {
        isScanning = true
        defer { isScanning = false }

        let found = try await client.scan()
        for device in found {
            if devices[device.id] == nil {
                devices[device.id] = MonitoredDevice(device: device)
            }
        }
        onUpdate?()
    }

    func startMonitoring() {
        for (id, monitored) in devices where monitoringTasks[id] == nil {
            monitoringTasks[id] = Task { @MainActor [weak self] in
                await self?.monitorWithRetry(id: id, device: monitored.device)
            }
        }
    }

    func stopMonitoring() {
        for (_, task) in monitoringTasks {
            task.cancel()
        }
        monitoringTasks.removeAll()
    }

    var sortedDevices: [MonitoredDevice] {
        devices.values.sorted { $0.device.name < $1.device.name }
    }

    // MARK: - Private

    private func monitorWithRetry(id: UUID, device: AranetDevice) async {
        var retryCount = 0

        while Task.isCancelled == false {
            let stream = client.monitor(from: device)

            for await result in stream {
                if Task.isCancelled { return }

                switch result {
                    case .success(let reading):
                        retryCount = 0
                        devices[id]?.reading = reading
                        devices[id]?.lastUpdated = Date()
                        onUpdate?()
                    case .failure:
                        break
                }
            }

            if Task.isCancelled { return }

            retryCount += 1
            if retryCount > maxRetries {
                NSLog("[SensorManager] Giving up on %@ after %d retries", device.name, maxRetries)
                return
            }

            let delay = baseRetryDelay * pow(2.0, Double(retryCount - 1))
            NSLog("[SensorManager] Reconnecting to %@ in %.0fs (attempt %d/%d)", device.name, delay, retryCount, maxRetries)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
