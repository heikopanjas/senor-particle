import AppKit
import AranetKit

class MenuManager: NSObject, NSMenuDelegate {
    let menu: NSMenu
    private weak var sensorManager: SensorManager?
    private var isOpen = false
    private var settingsWindowController: SettingsWindowController?
    private var rescanItem: NSMenuItem?
    private var deviceEntries: [UUID: (NSMenuItem, SensorDeviceView)] = [:]
    private var deviceOrder: [UUID] = []

    init(menu: NSMenu, sensorManager: SensorManager) {
        self.menu = menu
        self.sensorManager = sensorManager
        super.init()

        menu.delegate = self
        menu.addItem(NSMenuItem.separator())

        let rescan = NSMenuItem(title: "Rescan", action: #selector(rescan), keyEquivalent: "r")
        rescan.target = self
        menu.addItem(rescan)
        rescanItem = rescan

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Se\u{00F1}or Particle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

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

    func refreshIfNeeded() {
        guard isOpen, sensorManager != nil else { return }
        refreshIfNeededOnMainThread()
    }

    @objc private func handleReadingDidUpdate() {
        MenuTrackingRefresh.perform { [weak self] in
            self?.refreshIfNeededOnMainThread()
        }
    }

    private func refreshIfNeededOnMainThread() {
        guard isOpen, let sensorManager else { return }

        if sensorManager.isScanning || sensorManager.sortedDevices.isEmpty {
            refreshDeviceItems()
            return
        }

        let order = sensorManager.sortedDevices.map { $0.device.id }
        if order == deviceOrder {
            updateDeviceViewsInPlace()
        }
        else {
            refreshDeviceItems()
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        isOpen = true
        refreshDeviceItems()
    }

    func menuDidClose(_ menu: NSMenu) {
        isOpen = false
        clearDeviceItems()
    }

    // MARK: - Private

    private func refreshDeviceItems() {
        clearDeviceItems()

        guard let sensorManager else { return }

        rescanItem?.isEnabled = !sensorManager.isScanning

        if sensorManager.isScanning {
            let item = NSMenuItem(title: "Scanning for devices...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.insertItem(item, at: 0)
            return
        }

        let devices = sensorManager.sortedDevices

        if devices.isEmpty {
            let item = NSMenuItem(title: "No devices found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.insertItem(item, at: 0)
            return
        }

        var insertIndex = 0
        for (i, device) in devices.enumerated() {
            if i > 0 {
                menu.insertItem(.separator(), at: insertIndex)
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
            menu.insertItem(item, at: insertIndex)
            deviceEntries[device.device.id] = (item, view)
            deviceOrder.append(device.device.id)
            insertIndex += 1
        }
    }

    private func updateDeviceViewsInPlace() {
        guard let sensorManager else { return }

        for device in sensorManager.sortedDevices {
            guard let (item, view) = deviceEntries[device.device.id] else { continue }
            view.configure(
                device: device.device,
                reading: device.reading,
                lastUpdated: device.lastUpdated,
                updateSequence: device.updateSequence
            )
            reattachMenuItemView(item, view: view)
        }
        menu.update()
    }

    /// Reassigns the custom view so AppKit repaints menu item content during menu tracking.
    private func reattachMenuItemView(_ item: NSMenuItem, view: SensorDeviceView) {
        item.view = nil
        item.view = view
    }

    @objc private func rescan() {
        sensorManager?.rescan()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil, let sensorManager {
            settingsWindowController = SettingsWindowController(sensorManager: sensorManager)
        }
        settingsWindowController?.showAndBringToFront()
    }

    private func clearDeviceItems() {
        let fixedItemCount = 6
        while menu.items.count > fixedItemCount { menu.removeItem(at: 0) }
        deviceEntries.removeAll()
        deviceOrder.removeAll()
    }
}
