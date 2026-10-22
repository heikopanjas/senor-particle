import AppKit
import AranetKit
import Sparkle

/// Builds the status menu: one row per device above the fixed Rescan, Settings, About, and Quit items.
///
/// Device rows exist only while the menu is open. Every change notification causes at most one refresh, which updates
/// the rows in place when the device list is unchanged and rebuilds them otherwise.
final class MenuManager: NSObject {
    private struct DeviceMenuEntry {
        let item: NSMenuItem
        let view: SensorDeviceView
    }

    private static let deviceViewSize = NSSize(width: 280, height: 100)

    private let menu: NSMenu
    private weak var sensorManager: SensorManager?
    private let preferences: PreferencesStore
    private let updaterController: SPUStandardUpdaterController
    private var fixedItemCount = 0
    private var isOpen = false
    private var settingsWindowController: SettingsWindowController?
    private var rescanItem: NSMenuItem?
    private var deviceEntries: [UUID: DeviceMenuEntry] = [:]
    private var deviceOrder: [UUID] = []
    private var shownScanError: String?

    init(menu: NSMenu, sensorManager: SensorManager, preferences: PreferencesStore, updaterController: SPUStandardUpdaterController) {
        self.menu = menu
        self.sensorManager = sensorManager
        self.preferences = preferences
        self.updaterController = updaterController
        super.init()

        self.menu.delegate = self
        self.menu.addItem(.separator())

        let rescanItem = NSMenuItem(title: "Rescan", action: #selector(self.rescan), keyEquivalent: "r")
        rescanItem.target = self
        self.menu.addItem(rescanItem)
        self.rescanItem = rescanItem

        self.menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(self.openSettings), keyEquivalent: ",")
        settingsItem.target = self
        self.menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About \(Bundle.main.displayName)", action: #selector(self.openAbout), keyEquivalent: "")
        aboutItem.target = self
        self.menu.addItem(aboutItem)

        self.menu.addItem(.separator())

        self.menu.addItem(NSMenuItem(title: "Quit \(Bundle.main.displayName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        self.fixedItemCount = self.menu.items.count

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.handleContentDidChange), name: .sensorDevicesDidChange, object: sensorManager)
        center.addObserver(self, selector: #selector(self.handleContentDidChange), name: .aranetScanStateDidChange, object: sensorManager)
        center.addObserver(self, selector: #selector(self.handleContentDidChange), name: .preferencesDidChange, object: preferences)
    }

    // MARK: - Refresh

    @objc private func handleContentDidChange() -> Void {
        MenuTrackingRefresh.perform { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() -> Void {
        guard self.isOpen == true else { return }
        guard let sensorManager = self.sensorManager else { return }

        if self.canUpdateInPlace(sensorManager) == true {
            self.updateDeviceViewsInPlace(sensorManager)
        }
        else {
            self.rebuildDeviceItems()
        }
    }

    /// Whether the shown rows still match the device list, so they can be reconfigured instead of rebuilt.
    private func canUpdateInPlace(_ sensorManager: SensorManager) -> Bool {
        guard sensorManager.isScanning == false else { return false }
        guard sensorManager.scanError == self.shownScanError else { return false }
        guard self.deviceOrder.isEmpty == false else { return false }
        return sensorManager.sortedDevices.map(\.device.id) == self.deviceOrder
    }

    private func rebuildDeviceItems() -> Void {
        self.clearDeviceItems()

        guard let sensorManager = self.sensorManager else { return }

        self.rescanItem?.isEnabled = sensorManager.isScanning == false
        self.shownScanError = sensorManager.scanError

        if sensorManager.isScanning == true {
            self.insertInfoItem("Scanning for devices\u{2026}", at: 0)
            return
        }

        var insertIndex = 0
        if let scanError = sensorManager.scanError {
            self.insertInfoItem("\(scanError). Retrying automatically.", at: insertIndex)
            insertIndex += 1
        }

        let devices = sensorManager.sortedDevices
        guard devices.isEmpty == false else {
            if insertIndex == 0 {
                self.insertInfoItem("No devices found", at: insertIndex)
            }
            return
        }

        for monitored in devices {
            if insertIndex > 0 {
                self.menu.insertItem(.separator(), at: insertIndex)
                insertIndex += 1
            }

            let view = SensorDeviceView(frame: NSRect(origin: .zero, size: Self.deviceViewSize))
            self.configure(view, with: monitored)
            let item = NSMenuItem()
            item.view = view
            self.menu.insertItem(item, at: insertIndex)
            self.deviceEntries[monitored.device.id] = DeviceMenuEntry(item: item, view: view)
            self.deviceOrder.append(monitored.device.id)
            insertIndex += 1
        }
    }

    private func updateDeviceViewsInPlace(_ sensorManager: SensorManager) -> Void {
        for monitored in sensorManager.sortedDevices {
            guard let entry = self.deviceEntries[monitored.device.id] else { continue }
            self.configure(entry.view, with: monitored)
            self.reattachMenuItemView(entry.item, view: entry.view)
        }
        self.menu.update()
    }

    private func configure(_ view: SensorDeviceView, with monitored: MonitoredDevice) -> Void {
        view.configure(
            monitored,
            displayName: self.preferences.displayName(for: monitored),
            unitSystem: self.preferences.displayUnitSystem,
            degradedCycles: self.preferences.degradedCycles
        )
    }

    /// Reassigns the custom view so AppKit repaints menu item content during menu tracking.
    private func reattachMenuItemView(_ item: NSMenuItem, view: SensorDeviceView) -> Void {
        item.view = nil
        item.view = view
    }

    private func insertInfoItem(_ title: String, at index: Int) -> Void {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        self.menu.insertItem(item, at: index)
    }

    /// Removes everything above the fixed items, whose count is recorded when the menu is built.
    private func clearDeviceItems() -> Void {
        while self.menu.items.count > self.fixedItemCount {
            self.menu.removeItem(at: 0)
        }
        self.deviceEntries.removeAll()
        self.deviceOrder.removeAll()
    }

    // MARK: - Actions

    @objc private func rescan() -> Void {
        self.sensorManager?.rescan()
    }

    @objc private func openSettings() -> Void {
        self.resolvedSettingsWindowController()?.showAndBringToFront()
    }

    @objc private func openAbout() -> Void {
        self.resolvedSettingsWindowController()?.showAboutAndBringToFront()
    }

    /// Lazily creates the single shared Settings window so every menu entry reuses the same tab state.
    private func resolvedSettingsWindowController() -> SettingsWindowController? {
        if self.settingsWindowController == nil, let sensorManager = self.sensorManager {
            self.settingsWindowController = SettingsWindowController(
                sensorManager: sensorManager,
                preferences: self.preferences,
                updaterController: self.updaterController
            )
        }
        return self.settingsWindowController
    }
}

extension MenuManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) -> Void {
        self.isOpen = true
        self.rebuildDeviceItems()
    }

    func menuDidClose(_ menu: NSMenu) -> Void {
        self.isOpen = false
        self.clearDeviceItems()
    }
}
