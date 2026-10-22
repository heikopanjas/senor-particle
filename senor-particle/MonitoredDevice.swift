import AranetKit
import Foundation

/// One discovered device with its latest reading and the state of its monitoring loop.
nonisolated struct MonitoredDevice: Equatable {
    let device: AranetDevice
    var reading: AranetReading?
    var lastUpdated: Date?
    var updateSequence: UInt = 0
    var connectionState: ConnectionState = .connecting

    /// The name the device reports in its readings, falling back to its advertised Bluetooth name.
    var reportedName: String {
        return self.reading?.name ?? self.device.name
    }
}
