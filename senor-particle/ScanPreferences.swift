import Foundation

enum ScanPreferences {
    private static let timeoutKey = "scanTimeout"

    static let defaultTimeout: Double = 15

    /// Raw stored timeout, zero when never set by the user.
    static var storedTimeout: Double {
        get { UserDefaults.standard.double(forKey: timeoutKey) }
        set { UserDefaults.standard.set(newValue, forKey: timeoutKey) }
    }

    /// Effective scan timeout, falling back to the default when unset.
    static var timeout: Double {
        let stored = storedTimeout
        return stored > 0 ? stored : defaultTimeout
    }
}
