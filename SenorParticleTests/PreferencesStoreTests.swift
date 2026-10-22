import AranetKit
import Foundation
import Testing

@testable import senor_particle

@Suite("PreferencesStore")
struct PreferencesStoreTests {
    private let temporary: TemporaryDefaults
    private let center = NotificationCenter()
    private let recorder: NotificationRecorder
    private let store: PreferencesStore

    init() throws {
        self.temporary = try TemporaryDefaults()
        self.recorder = NotificationRecorder(name: .preferencesDidChange, center: self.center)
        self.store = PreferencesStore(defaults: self.temporary.defaults, notificationCenter: self.center, locale: Locale(identifier: "de_DE"))
    }

    private var defaults: UserDefaults {
        return self.temporary.defaults
    }

    /// The raw values of the preferences named by the recorded notifications, in posting order.
    private var changedPreferences: [String] {
        return self.recorder.userInfoValues(forKey: PreferencesStore.changedPreferenceUserInfoKey, as: String.self)
    }

    @Test("Unset preferences read their defaults")
    func unsetPreferencesReadDefaults() -> Void {
        let deviceId = UUID()

        #expect(self.store.scanTimeout == PreferencesStore.defaultScanTimeout)
        #expect(self.store.degradedCycles == PreferencesStore.defaultDegradedCycles)
        #expect(self.store.notificationPersonality == .professional)
        #expect(self.store.displayUnitSystem == .metric)
        #expect(self.store.statusBarSelection == nil)
        #expect(self.store.notificationsEnabled(for: deviceId) == false)
        #expect(self.store.deviceName(for: deviceId) == nil)
        #expect(self.recorder.notifications.isEmpty == true)
    }

    @Test("The locale decides the unit system until the user picks one", arguments: [("de_DE", DisplayUnitSystem.metric), ("en_US", .imperial)])
    func localeDecidesUnitSystem(identifier: String, expected: DisplayUnitSystem) -> Void {
        let store = PreferencesStore(defaults: self.defaults, notificationCenter: self.center, locale: Locale(identifier: identifier))

        #expect(store.localeUnitSystem == expected)
        #expect(store.displayUnitSystem == expected)
    }

    @Test("A setter posts once per change and names the preference")
    func settersPostOncePerChange() -> Void {
        let deviceId = UUID()

        self.store.scanTimeout = 30
        self.store.scanTimeout = 30
        self.store.degradedCycles = 5
        self.store.degradedCycles = 5
        self.store.displayUnitSystem = .imperial
        self.store.displayUnitSystem = .imperial
        self.store.notificationPersonality = .snarky
        self.store.notificationPersonality = .snarky
        self.store.setNotificationsEnabled(true, for: deviceId)
        self.store.setNotificationsEnabled(true, for: deviceId)
        self.store.setDeviceName("Office", for: deviceId)
        self.store.setDeviceName("Office", for: deviceId)
        self.store.toggleStatusBarMetric(.co2, of: deviceId)

        let expected: [PreferencesStore.Preference] = [
            .scanTimeout,
            .degradedCycles,
            .displayUnitSystem,
            .notificationPersonality,
            .notificationsEnabled,
            .deviceName,
            .statusBarSelection
        ]
        #expect(self.changedPreferences == expected.map { $0.rawValue })
        #expect(self.recorder.notifications.allSatisfy { $0.object as? PreferencesStore === self.store } == true)
    }

    @Test("Storing the value a preference already reads posts nothing")
    func storingCurrentValuePostsNothing() -> Void {
        self.store.scanTimeout = PreferencesStore.defaultScanTimeout
        self.store.degradedCycles = PreferencesStore.defaultDegradedCycles
        self.store.displayUnitSystem = .metric
        self.store.notificationPersonality = .professional
        self.store.setNotificationsEnabled(false, for: UUID())
        self.store.setDeviceName("", for: UUID())
        self.store.statusBarSelection = nil

        #expect(self.recorder.notifications.isEmpty == true)
    }

    @Test("Scan timeouts that are not positive read as the default", arguments: [0.0, -5.0])
    func nonPositiveScanTimeoutReadsDefault(stored: Double) -> Void {
        self.defaults.set(stored, forKey: "scanTimeout")

        #expect(self.store.scanTimeout == PreferencesStore.defaultScanTimeout)
    }

    @Test("The degraded threshold is clamped to its range when set")
    func degradedCyclesClampOnWrite() -> Void {
        self.store.degradedCycles = 0
        #expect(self.store.degradedCycles == PreferencesStore.degradedCyclesRange.lowerBound)

        self.store.degradedCycles = 42
        #expect(self.store.degradedCycles == PreferencesStore.degradedCyclesRange.upperBound)
    }

    @Test("Stored degraded thresholds outside the range read as the default or the maximum", arguments: [(0, 3), (-2, 3), (7, 7), (99, 10)])
    func storedDegradedCyclesAreClamped(stored: Int, expected: Int) -> Void {
        self.defaults.set(stored, forKey: "degradedSituationCycles")

        #expect(self.store.degradedCycles == expected)
    }

    @Test(
        "Stored personalities map by raw value, and unknown ones read as professional",
        arguments: [(1, NotificationPersonality.friendly), (3, .professional), (4, .overkill), (99, .professional)]
    )
    func storedPersonalities(stored: Int, expected: NotificationPersonality) -> Void {
        self.defaults.set(stored, forKey: "notificationPersonality")

        #expect(self.store.notificationPersonality == expected)
    }

    @Test("An unknown stored unit system falls back to the locale")
    func unknownUnitSystemFallsBackToLocale() -> Void {
        self.defaults.set("nautical", forKey: "displayUnitSystem")

        #expect(self.store.displayUnitSystem == .metric)
    }

    @Test("Disabling notifications removes the stored flag")
    func disablingNotificationsRemovesFlag() -> Void {
        let deviceId = UUID()
        let key = "notifications.\(deviceId.uuidString)"

        self.store.setNotificationsEnabled(true, for: deviceId)
        #expect(self.store.notificationsEnabled(for: deviceId) == true)
        #expect(self.defaults.object(forKey: key) != nil)

        self.store.setNotificationsEnabled(false, for: deviceId)
        #expect(self.store.notificationsEnabled(for: deviceId) == false)
        #expect(self.defaults.object(forKey: key) == nil)
        #expect(self.recorder.notifications.count == 2)
    }

    @Test("A custom name replaces the reported name, and an empty name restores it")
    func customDeviceNames() -> Void {
        let device = ReadingFixtures.device(named: "Aranet4 Advertised")
        var monitored = MonitoredDevice(device: device)
        #expect(self.store.displayName(for: monitored) == "Aranet4 Advertised")

        monitored.reading = ReadingFixtures.aranet4()
        #expect(self.store.displayName(for: monitored) == ReadingFixtures.aranet4Name)

        self.store.setDeviceName("Office", for: device.id)
        #expect(self.store.displayName(for: monitored) == "Office")

        self.store.setDeviceName("", for: device.id)
        #expect(self.store.deviceName(for: device.id) == nil)
        #expect(self.store.displayName(for: monitored) == ReadingFixtures.aranet4Name)
        #expect(self.changedPreferences == ["deviceName", "deviceName"])
    }

    @Test("The single metric of earlier versions is read, then removed by the next write")
    func legacyStatusBarMetricMigrates() -> Void {
        let deviceId = UUID()
        self.defaults.set(deviceId.uuidString, forKey: "statusBarDisplay.deviceId")
        self.defaults.set("co2", forKey: "statusBarDisplay.metric")

        #expect(self.store.statusBarSelection == StatusBarDisplaySelection(deviceId: deviceId, metrics: [.co2]))

        self.store.toggleStatusBarMetric(.temperature, of: deviceId)

        #expect(self.store.statusBarSelection?.metrics == [.co2, .temperature])
        #expect(self.defaults.string(forKey: "statusBarDisplay.metric") == nil)
        #expect(self.defaults.stringArray(forKey: "statusBarDisplay.metrics") == ["co2", "temperature"])
    }

    @Test("A stored selection drops unknown metrics, and reads as nil without a valid device or metric")
    func storedSelectionValidation() -> Void {
        let deviceId = UUID()
        self.defaults.set(deviceId.uuidString, forKey: "statusBarDisplay.deviceId")
        self.defaults.set(["sparkles", "humidity"], forKey: "statusBarDisplay.metrics")
        #expect(self.store.statusBarSelection?.metrics == [.humidity])

        self.defaults.set(["sparkles"], forKey: "statusBarDisplay.metrics")
        #expect(self.store.statusBarSelection == nil)

        self.defaults.set(["co2"], forKey: "statusBarDisplay.metrics")
        self.defaults.set("not-a-uuid", forKey: "statusBarDisplay.deviceId")
        #expect(self.store.statusBarSelection == nil)
    }

    @Test("Unpinning the last metric clears the stored selection")
    func unpinningLastMetricClearsSelection() -> Void {
        let deviceId = UUID()

        self.store.toggleStatusBarMetric(.co2, of: deviceId)
        #expect(self.store.statusBarSelection?.deviceId == deviceId)

        self.store.toggleStatusBarMetric(.co2, of: deviceId)
        #expect(self.store.statusBarSelection == nil)
        #expect(self.defaults.string(forKey: "statusBarDisplay.deviceId") == nil)
        #expect(self.defaults.object(forKey: "statusBarDisplay.metrics") == nil)
    }
}
