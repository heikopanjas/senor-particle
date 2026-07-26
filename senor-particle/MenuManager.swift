import AppKit
import AranetKit
import Sparkle

class MenuManager: NSObject, NSMenuDelegate {
    let menu: NSMenu
    private weak var sensorManager: SensorManager?
    private let updaterController: SPUStandardUpdaterController
    private var isOpen = false
    private var settingsWindowController: SettingsWindowController?
    private var rescanItem: NSMenuItem?
    private var deviceEntries: [UUID: (NSMenuItem, SensorDeviceView)] = [:]
    private var deviceOrder: [UUID] = []

    init(menu: NSMenu, sensorManager: SensorManager, updaterController: SPUStandardUpdaterController) {
        self.menu = menu
        self.sensorManager = sensorManager
        self.updaterController = updaterController
        super.init()

        self.menu.delegate = self
        self.menu.addItem(NSMenuItem.separator())

        let rescan = NSMenuItem(title: "Rescan", action: #selector(rescan), keyEquivalent: "r")
        rescan.target = self
        self.menu.addItem(rescan)
        self.rescanItem = rescan

        self.menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        self.menu.addItem(settingsItem)

        self.menu.addItem(NSMenuItem.separator())

        self.menu.addItem(NSMenuItem(title: "Quit Se\u{00F1}or Particle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReadingDidUpdate),
            name: .aranetReadingDidUpdate,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refreshIfNeeded() -> Void {
        guard self.isOpen == true, self.sensorManager != nil else { return }
        self.refreshIfNeededOnMainThread()
    }

    @objc private func handleReadingDidUpdate() -> Void {
        MenuTrackingRefresh.perform { [weak self] in
            self?.refreshIfNeededOnMainThread()
        }
    }

    private func refreshIfNeededOnMainThread() -> Void {
        guard self.isOpen == true, let sensorManager = self.sensorManager else { return }

        if sensorManager.isScanning == true || sensorManager.sortedDevices.isEmpty == true {
            self.refreshDeviceItems()
            return
        }

        let order = sensorManager.sortedDevices.map { $0.device.id }
        if order == self.deviceOrder {
            self.updateDeviceViewsInPlace()
        }
        else {
            self.refreshDeviceItems()
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) -> Void {
        self.isOpen = true
        self.refreshDeviceItems()
    }

    func menuDidClose(_ menu: NSMenu) -> Void {
        self.isOpen = false
        self.clearDeviceItems()
    }

    // MARK: - Private

    private func refreshDeviceItems() -> Void {
        self.clearDeviceItems()

        guard let sensorManager = self.sensorManager else { return }

        self.rescanItem?.isEnabled = sensorManager.isScanning == false

        if sensorManager.isScanning == true {
            let item = NSMenuItem(title: "Scanning for devices...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            self.menu.insertItem(item, at: 0)
            return
        }

        let devices = sensorManager.sortedDevices

        if devices.isEmpty == true {
            let item = NSMenuItem(title: "No devices found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            self.menu.insertItem(item, at: 0)
            return
        }

        var insertIndex = 0
        for (i, device) in devices.enumerated() {
            if i > 0 {
                self.menu.insertItem(.separator(), at: insertIndex)
                insertIndex += 1
            }
            let item = NSMenuItem()
            let view = SensorDeviceView(frame: NSRect(x: 0, y: 0, width: 280, height: 100))
            view.configure(
                device: device.device,
                reading: device.reading,
                lastUpdated: device.lastUpdated,
                updateSequence: device.updateSequence
            )
            item.view = view
            self.menu.insertItem(item, at: insertIndex)
            self.deviceEntries[device.device.id] = (item, view)
            self.deviceOrder.append(device.device.id)
            insertIndex += 1
        }
    }

    private func updateDeviceViewsInPlace() -> Void {
        guard let sensorManager = self.sensorManager else { return }

        for device in sensorManager.sortedDevices {
            guard let (item, view) = self.deviceEntries[device.device.id] else { continue }
            view.configure(
                device: device.device,
                reading: device.reading,
                lastUpdated: device.lastUpdated,
                updateSequence: device.updateSequence
            )
            self.reattachMenuItemView(item, view: view)
        }
        self.menu.update()
    }

    /// Reassigns the custom view so AppKit repaints menu item content during menu tracking.
    private func reattachMenuItemView(_ item: NSMenuItem, view: SensorDeviceView) -> Void {
        item.view = nil
        item.view = view
    }

    @objc private func rescan() -> Void {
        self.sensorManager?.rescan()
    }

    @objc private func openSettings() -> Void {
        if self.settingsWindowController == nil, let sensorManager = self.sensorManager {
            self.settingsWindowController = SettingsWindowController(sensorManager: sensorManager, updaterController: self.updaterController)
        }
        self.settingsWindowController?.showAndBringToFront()
    }

    private func clearDeviceItems() -> Void {
        let fixedItemCount = 6
        while self.menu.items.count > fixedItemCount { self.menu.removeItem(at: 0) }
        self.deviceEntries.removeAll()
        self.deviceOrder.removeAll()
    }
}
