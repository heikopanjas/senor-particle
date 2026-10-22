import Testing

@testable import senor_particle

@Suite("ConnectionState")
struct ConnectionStateTests {
    @Test("Connecting and connected need no explanation", arguments: [ConnectionState.connecting, .connected])
    func healthyStatesHaveNoText(state: ConnectionState) -> Void {
        #expect(state.menuText == nil)
        #expect(state.columnText == nil)
    }

    @Test("Reconnecting names the attempt")
    func reconnectingText() -> Void {
        let state = ConnectionState.reconnecting(attempt: 2, of: 5)

        #expect(state.menuText == "Reconnecting, attempt 2 of 5\u{2026}")
        #expect(state.columnText == "Reconnecting (2/5)")
    }

    @Test("A failure explains the reason and the way out")
    func failedText() -> Void {
        let state = ConnectionState.failed("Failed to connect to device")

        #expect(state.menuText == "Monitoring stopped: Failed to connect to device. Choose Rescan to try again.")
        #expect(state.columnText == "Stopped")
    }
}
