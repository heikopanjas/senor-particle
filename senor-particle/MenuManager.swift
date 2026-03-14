import AppKit

class MenuManager: NSObject, NSMenuDelegate {
    let menu: NSMenu
    private weak var sensorManager: SensorManager?
    private var isOpen = false

    init(menu: NSMenu, sensorManager: SensorManager) {
        self.menu = menu
        self.sensorManager = sensorManager
        super.init()

        menu.delegate = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Se\u{00F1}or Particle",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
    }

    func refreshIfNeeded() {
        guard isOpen else { return }
        refreshDeviceItems()
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
            view.configure(device: device.device, reading: device.reading, lastUpdated: device.lastUpdated)
            item.view = view
            menu.insertItem(item, at: insertIndex)
            insertIndex += 1
        }
    }

    private func clearDeviceItems() {
        let fixedItemCount = 2
        while menu.items.count > fixedItemCount {
            menu.removeItem(at: 0)
        }
    }
}
