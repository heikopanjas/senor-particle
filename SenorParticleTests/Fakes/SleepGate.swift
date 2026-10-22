import Foundation
import Testing

/// A fake `sleep` that suspends callers until the test releases them, recording every requested delay.
///
/// Cancelling a suspended caller's task resumes it by throwing `CancellationError`, as `Task.sleep` does.
final class SleepGate {
    private var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    private(set) var requestedDelays: [TimeInterval] = []

    /// Number of callers currently suspended.
    var waiting: Int {
        return self.waiters.count
    }

    func sleep(_ delay: TimeInterval) async throws -> Void {
        self.requestedDelays.append(delay)
        let id = UUID()

        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                self.waiters[id] = continuation
            }
        } onCancel: {
            Task { @MainActor in
                self.cancelWaiter(id)
            }
        }
    }

    /// Resumes every suspended caller normally; nobody sleeping is an issue, because the test released too early.
    func release() -> Void {
        let waiters = self.waiters.values
        if waiters.isEmpty == true {
            Issue.record("release() found no sleeping caller")
        }
        self.waiters = [:]
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func cancelWaiter(_ id: UUID) -> Void {
        guard let waiter = self.waiters.removeValue(forKey: id) else { return }
        waiter.resume(throwing: CancellationError())
    }
}
