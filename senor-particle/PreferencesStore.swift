import Foundation

extension Notification.Name {
    /// Posted by `PreferencesStore` after a stored preference changed; `userInfo` names the preference.
    static let preferencesDidChange = Notification.Name("preferencesDidChange")
}

/// Every user preference, persisted in one injectable `UserDefaults` domain.
///
/// Setters write and post `preferencesDidChange` only when the effective value changes. Tests pass their own
/// `UserDefaults` suite, notification center, and locale.
final class PreferencesStore {
    /// The preferences announced through `preferencesDidChange`.
    enum Preference: String {
        case scanTimeout
        case degradedCycles
        case displayUnitSystem
        case notificationPersonality
        case notificationsEnabled
        case deviceName
        case statusBarSelection
    }

    private enum StorageKey {
        static let scanTimeout = "scanTimeout"
        static let degradedCycles = "degradedSituationCycles"
        static let displayUnitSystem = "displayUnitSystem"
        static let notificationPersonality = "notificationPersonality"
        static let statusBarDeviceId = "statusBarDisplay.deviceId"
        static let statusBarMetrics = "statusBarDisplay.metrics"
        /// The single metric stored by versions before two-metric support; read once and removed on the next write.
        static let legacyStatusBarMetric = "statusBarDisplay.metric"

        static func notificationsEnabled(for deviceId: UUID) -> String {
            return "notifications.\(deviceId.uuidString)"
        }

        static func deviceName(for deviceId: UUID) -> String {
            return "deviceName.\(deviceId.uuidString)"
        }
    }

    static let shared = PreferencesStore(defaults: .standard)

    /// `userInfo` key of `preferencesDidChange`, holding the changed `Preference` raw value.
    static let changedPreferenceUserInfoKey = "preference"
    static let defaultScanTimeout: TimeInterval = 15
    static let scanTimeoutRange: ClosedRange<TimeInterval> = 10 ... 60
    static let defaultDegradedCycles = 3
    static let degradedCyclesRange: ClosedRange<Int> = 1 ... 10

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let locale: Locale

    init(defaults: UserDefaults, notificationCenter: NotificationCenter = .default, locale: Locale = .current) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.locale = locale
    }

    // MARK: - Scanning

    /// Seconds a scan waits for devices; the default applies until the user moves the slider.
    var scanTimeout: TimeInterval {
        get {
            let stored = self.defaults.double(forKey: StorageKey.scanTimeout)
            guard stored > 0 else { return Self.defaultScanTimeout }
            return stored
        }
        set {
            guard newValue != self.scanTimeout else { return }
            self.defaults.set(newValue, forKey: StorageKey.scanTimeout)
            self.post(.scanTimeout)
        }
    }

    // MARK: - Update cycle

    /// Missed update intervals after which the progress bar shows a degraded situation, clamped to `degradedCyclesRange`.
    var degradedCycles: Int {
        get {
            let stored = self.defaults.integer(forKey: StorageKey.degradedCycles)
            guard stored >= Self.degradedCyclesRange.lowerBound else { return Self.defaultDegradedCycles }
            return min(stored, Self.degradedCyclesRange.upperBound)
        }
        set {
            let clamped = min(max(newValue, Self.degradedCyclesRange.lowerBound), Self.degradedCyclesRange.upperBound)
            guard clamped != self.degradedCycles else { return }
            self.defaults.set(clamped, forKey: StorageKey.degradedCycles)
            self.post(.degradedCycles)
        }
    }

    // MARK: - Display

    /// The unit system chosen in Settings, or the locale's system until the user picks one.
    var displayUnitSystem: DisplayUnitSystem {
        get {
            guard let raw = self.defaults.string(forKey: StorageKey.displayUnitSystem) else { return self.localeUnitSystem }
            guard let unitSystem = DisplayUnitSystem(rawValue: raw) else { return self.localeUnitSystem }
            return unitSystem
        }
        set {
            guard newValue != self.displayUnitSystem else { return }
            self.defaults.set(newValue.rawValue, forKey: StorageKey.displayUnitSystem)
            self.post(.displayUnitSystem)
        }
    }

    /// The unit system of the injected locale.
    var localeUnitSystem: DisplayUnitSystem {
        return self.locale.measurementSystem == .metric ? .metric : .imperial
    }

    // MARK: - Notifications

    /// The tone of status notifications; unknown stored values read as `professional`.
    var notificationPersonality: NotificationPersonality {
        get {
            let raw = self.defaults.integer(forKey: StorageKey.notificationPersonality)
            return NotificationPersonality(rawValue: raw) ?? .professional
        }
        set {
            guard newValue != self.notificationPersonality else { return }
            self.defaults.set(newValue.rawValue, forKey: StorageKey.notificationPersonality)
            self.post(.notificationPersonality)
        }
    }

    func notificationsEnabled(for deviceId: UUID) -> Bool {
        return self.defaults.bool(forKey: StorageKey.notificationsEnabled(for: deviceId))
    }

    func setNotificationsEnabled(_ enabled: Bool, for deviceId: UUID) -> Void {
        guard enabled != self.notificationsEnabled(for: deviceId) else { return }
        let key = StorageKey.notificationsEnabled(for: deviceId)
        if enabled == true {
            self.defaults.set(true, forKey: key)
        }
        else {
            self.defaults.removeObject(forKey: key)
        }
        self.post(.notificationsEnabled)
    }

    // MARK: - Device names

    func deviceName(for deviceId: UUID) -> String? {
        return self.defaults.string(forKey: StorageKey.deviceName(for: deviceId))
    }

    /// Stores a custom name; an empty name removes it, so the reported name shows again.
    func setDeviceName(_ name: String, for deviceId: UUID) -> Void {
        let customName: String? = name.isEmpty == true ? nil : name
        guard customName != self.deviceName(for: deviceId) else { return }
        let key = StorageKey.deviceName(for: deviceId)
        if let customName {
            self.defaults.set(customName, forKey: key)
        }
        else {
            self.defaults.removeObject(forKey: key)
        }
        self.post(.deviceName)
    }

    /// The custom name of the device when set, otherwise the name it reports.
    func displayName(for monitored: MonitoredDevice) -> String {
        return self.deviceName(for: monitored.device.id) ?? monitored.reportedName
    }

    // MARK: - Status item

    /// The pinned device and metrics; reads the single metric of earlier versions when no metric list is stored.
    var statusBarSelection: StatusBarDisplaySelection? {
        get {
            guard let deviceIdString = self.defaults.string(forKey: StorageKey.statusBarDeviceId) else { return nil }
            guard let deviceId = UUID(uuidString: deviceIdString) else { return nil }

            let storedMetrics = self.defaults.stringArray(forKey: StorageKey.statusBarMetrics) ?? self.legacyStatusBarMetrics
            let metrics = storedMetrics.compactMap { StatusBarDisplayMetric(rawValue: $0) }
            return StatusBarDisplaySelection(deviceId: deviceId, metrics: metrics)
        }
        set {
            guard newValue != self.statusBarSelection else { return }
            if let newValue {
                self.defaults.set(newValue.deviceId.uuidString, forKey: StorageKey.statusBarDeviceId)
                self.defaults.set(newValue.metrics.map(\.rawValue), forKey: StorageKey.statusBarMetrics)
            }
            else {
                self.defaults.removeObject(forKey: StorageKey.statusBarDeviceId)
                self.defaults.removeObject(forKey: StorageKey.statusBarMetrics)
            }
            self.defaults.removeObject(forKey: StorageKey.legacyStatusBarMetric)
            self.post(.statusBarSelection)
        }
    }

    /// Pins or unpins `metric` of `deviceId` following the rules of `StatusBarDisplaySelection.toggling`.
    func toggleStatusBarMetric(_ metric: StatusBarDisplayMetric, of deviceId: UUID) -> Void {
        self.statusBarSelection = StatusBarDisplaySelection.toggling(metric, of: deviceId, in: self.statusBarSelection)
    }

    // MARK: - Private

    private var legacyStatusBarMetrics: [String] {
        guard let legacyMetric = self.defaults.string(forKey: StorageKey.legacyStatusBarMetric) else { return [] }
        return [legacyMetric]
    }

    private func post(_ preference: Preference) -> Void {
        self.notificationCenter.post(
            name: .preferencesDidChange,
            object: self,
            userInfo: [Self.changedPreferenceUserInfoKey: preference.rawValue]
        )
    }
}
