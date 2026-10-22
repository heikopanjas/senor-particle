import AranetKit
import Foundation
import Testing

/// A `SensorClient` whose scans wait for the test, and whose monitor streams the test feeds and finishes.
final class FakeSensorClient: SensorClient {
    typealias MonitorResult = Result<AranetReading, any Error>

    var verbose = false
    private(set) var scanTimeouts: [TimeInterval] = []
    /// Monitor streams that ended, because the test finished them or because their consumer stopped iterating.
    private(set) var terminations = 0
    private var scanContinuations: [CheckedContinuation<[AranetDevice], any Error>] = []
    private var monitorContinuations: [UUID: [AsyncStream<MonitorResult>.Continuation]] = [:]

    /// Scans waiting for `finishScans(returning:)` or `failScans(with:)`.
    var pendingScans: Int {
        return self.scanContinuations.count
    }

    /// How many monitor streams were opened for `device`.
    func monitorCallCount(for device: AranetDevice) -> Int {
        return self.monitorContinuations[device.id]?.count ?? 0
    }

    func scan(timeout: TimeInterval) async throws -> [AranetDevice] {
        self.scanTimeouts.append(timeout)
        return try await withCheckedThrowingContinuation { continuation in
            self.scanContinuations.append(continuation)
        }
    }

    func readCurrentReadings(from device: AranetDevice) async throws -> AranetReading {
        throw AranetError.readFailed
    }

    func monitor(from device: AranetDevice) -> AsyncStream<MonitorResult> {
        let (stream, continuation) = AsyncStream<MonitorResult>.makeStream()
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.terminations += 1
            }
        }
        self.monitorContinuations[device.id, default: []].append(continuation)
        return stream
    }

    // MARK: - Test control

    func finishScans(returning devices: [AranetDevice]) -> Void {
        let continuations = self.takeScanContinuations()
        for continuation in continuations {
            continuation.resume(returning: devices)
        }
    }

    func failScans(with error: AranetError) -> Void {
        let continuations = self.takeScanContinuations()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }

    /// Delivers `result` on the newest monitor stream of `device`.
    func yield(_ result: MonitorResult, to device: AranetDevice) -> Void {
        guard let continuation = self.monitorContinuations[device.id]?.last else {
            Issue.record("No monitor stream is open for \(device.name)")
            return
        }
        continuation.yield(result)
    }

    /// Ends the newest monitor stream of `device`, as AranetKit does after a failed read.
    func finishLatestStream(for device: AranetDevice) -> Void {
        guard let continuation = self.monitorContinuations[device.id]?.last else {
            Issue.record("No monitor stream is open for \(device.name)")
            return
        }
        continuation.finish()
    }

    private func takeScanContinuations() -> [CheckedContinuation<[AranetDevice], any Error>] {
        let continuations = self.scanContinuations
        if continuations.isEmpty == true {
            Issue.record("No scan is waiting")
        }
        self.scanContinuations = []
        return continuations
    }
}
