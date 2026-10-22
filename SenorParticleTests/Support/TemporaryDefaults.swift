import Foundation
import Testing

/// A `UserDefaults` suite of its own for one test, removed when the instance is released.
final class TemporaryDefaults {
    let defaults: UserDefaults
    private let suiteName: String

    init() throws {
        let suiteName = "com.panjas.senor-particle.tests.\(UUID().uuidString)"
        self.defaults = try #require(UserDefaults(suiteName: suiteName))
        self.suiteName = suiteName
    }

    isolated deinit {
        self.defaults.removePersistentDomain(forName: self.suiteName)
    }
}
