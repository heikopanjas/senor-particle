import Foundation

/// Facts about the process the app runs in.
enum AppEnvironment {
    /// True when the app hosts the unit test bundle; the app then skips Bluetooth, Sparkle, and status item setup.
    static let isRunningUnitTests: Bool = {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil {
            return true
        }
        return environment["XCTestBundlePath"] != nil
    }()
}
