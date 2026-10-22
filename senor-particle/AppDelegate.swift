import AranetKit
import Cocoa
import Sparkle

/// Owns the status item and the long-lived managers, and keeps the status item in sync with the latest readings.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let airLabel = "AIR"
    private static let radiationLabel = "RAD"

    private let preferences = PreferencesStore.shared
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: AppEnvironment.isRunningUnitTests == false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private let statusItemDisplayView = StatusItemDisplayView()
    private let statusItemPlaceholderView = StatusItemPlaceholderView()
    private var statusItem: NSStatusItem?
    private var sensorManager: SensorManager?
    private var menuManager: MenuManager?
    private var notificationManager: NotificationManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) -> Void {
        guard AppEnvironment.isRunningUnitTests == false else { return }

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        let menu = NSMenu()
        statusItem.menu = menu
        self.showPlaceholder()

        let sensorManager = SensorManager(preferences: self.preferences)
        self.sensorManager = sensorManager
        self.menuManager = MenuManager(
            menu: menu,
            sensorManager: sensorManager,
            preferences: self.preferences,
            updaterController: self.updaterController
        )
        self.notificationManager = NotificationManager(sensorManager: sensorManager, preferences: self.preferences)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.handleStatusItemInputsDidChange), name: .sensorDevicesDidChange, object: sensorManager)
        center.addObserver(self, selector: #selector(self.handleScanStateChange), name: .aranetScanStateDidChange, object: sensorManager)
        center.addObserver(self, selector: #selector(self.handleStatusItemInputsDidChange), name: .preferencesDidChange, object: self.preferences)

        sensorManager.rescan()
    }

    func applicationWillTerminate(_ aNotification: Notification) -> Void {
        self.sensorManager?.stopMonitoring()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Status Item

    @objc private func handleStatusItemInputsDidChange() -> Void {
        self.scheduleStatusItemRefresh()
    }

    @objc private func handleScanStateChange() -> Void {
        if self.sensorManager?.isScanning == true {
            self.showPlaceholder()
        }
        else {
            self.scheduleStatusItemRefresh()
        }
    }

    /// Refreshes on the common run loop modes, so the status item also updates while the menu is open.
    private func scheduleStatusItemRefresh() -> Void {
        MenuTrackingRefresh.perform { [weak self] in
            self?.updateStatusItem()
        }
    }

    /// Shows the pinned values, or the first available values of the first device with a reading, or the placeholder.
    private func updateStatusItem() -> Void {
        guard let sensorManager = self.sensorManager else { return }

        let unitSystem = self.preferences.displayUnitSystem
        let reading: AranetReading?
        let values: [String]
        if let selection = self.preferences.statusBarSelection {
            reading = sensorManager.devices[selection.deviceId]?.reading
            values = reading.map { selection.valueStrings(for: $0, unitSystem: unitSystem) } ?? []
        }
        else {
            reading = sensorManager.sortedDevices.first { $0.reading != nil }?.reading
            values = reading.map { StatusBarDisplayMetric.defaultValueStrings(for: $0, unitSystem: unitSystem) } ?? []
        }

        guard let reading else {
            self.showPlaceholder()
            return
        }
        guard values.isEmpty == false else {
            self.showPlaceholder()
            return
        }

        self.showValues(StatusItemDisplayValue(label: Self.label(for: reading), values: values))
    }

    private func showValues(_ value: StatusItemDisplayValue) -> Void {
        self.statusItemPlaceholderView.stopAnimating()
        self.statusItemPlaceholderView.removeFromSuperview()
        self.statusItemDisplayView.configure(value: value)
        self.installStatusItemView(self.statusItemDisplayView, width: StatusItemDisplayView.requiredWidth(for: value))
    }

    private func showPlaceholder() -> Void {
        self.statusItemDisplayView.removeFromSuperview()
        self.installStatusItemView(self.statusItemPlaceholderView, width: StatusItemPlaceholderView.requiredWidth())
        self.statusItemPlaceholderView.startAnimating()
    }

    /// Makes `view` the only content of the status item button, sized to `width` and the menu bar height.
    private func installStatusItemView(_ view: NSView, width: CGFloat) -> Void {
        guard let statusItem = self.statusItem else { return }
        guard let button = statusItem.button else { return }

        let height = button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness
        statusItem.length = width
        button.title = ""
        button.image = nil

        if view.superview !== button {
            view.removeFromSuperview()
            button.addSubview(view)
        }

        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        view.autoresizingMask = [.height]
        button.needsDisplay = true
        button.displayIfNeeded()
        button.window?.displayIfNeeded()
    }

    private static func label(for reading: AranetReading) -> String {
        return reading.deviceType == .aranetRadiation ? Self.radiationLabel : Self.airLabel
    }
}
