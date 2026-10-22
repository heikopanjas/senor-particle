import AranetKit

/// A change of a device's status color between two readings.
nonisolated struct StatusTransition: Equatable {
    let from: AranetStatusColor
    let to: AranetStatusColor
}
