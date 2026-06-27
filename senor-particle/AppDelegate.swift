import AranetKit
import Cocoa

@main class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var sensorManager: SensorManager?
    private var menuManager: MenuManager?
    private var notificationManager: NotificationManager?
    private let statusItemDisplayView = StatusItemDisplayView()

    func applicationDidFinishLaunching(_ aNotification: Notification) -> Void {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        statusItem.button?.title = " \u{2026}"
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.image = self.statusBarPlaceholderSymbol()
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        let menu = NSMenu()
        statusItem.menu = menu

        let sensorManager = SensorManager()
        self.sensorManager = sensorManager

        self.menuManager = MenuManager(menu: menu, sensorManager: sensorManager)
        self.notificationManager = NotificationManager(sensorManager: sensorManager)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReadingDidUpdate),
            name: .aranetReadingDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScanStateChange),
            name: .aranetScanStateDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStatusBarDisplayPreferenceDidChange),
            name: .statusBarDisplayPreferenceDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayUnitSystemPreferenceDidChange),
            name: .displayUnitSystemPreferenceDidChange,
            object: nil
        )

        Task {
            do {
                try await sensorManager.scan()
                sensorManager.startMonitoring()
                MenuTrackingRefresh.perform { [weak self] in
                    self?.updateStatusBar()
                    self?.menuManager?.refreshIfNeeded()
                }
            }
            catch { NSLog("[AppDelegate] Scan failed: %@", error.localizedDescription) }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) -> Void { self.sensorManager?.stopMonitoring() }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { return true }

    // MARK: - Status Bar

    @objc private func handleReadingDidUpdate() -> Void {
        MenuTrackingRefresh.perform { [weak self] in
            self?.updateStatusBar()
            self?.menuManager?.refreshIfNeeded()
        }
    }

    @objc private func handleScanStateChange() -> Void {
        if self.sensorManager?.isScanning == true {
            self.setStatusBarPlaceholder()
        }
        else if self.sensorManager?.sortedDevices.first(where: { $0.reading != nil }) == nil {
            self.setStatusBarPlaceholder()
        }
    }

    @objc private func handleStatusBarDisplayPreferenceDidChange() -> Void {
        MenuTrackingRefresh.perform { [weak self] in
            self?.updateStatusBar()
        }
    }

    @objc private func handleDisplayUnitSystemPreferenceDidChange() -> Void {
        MenuTrackingRefresh.perform { [weak self] in
            self?.updateStatusBar()
            self?.menuManager?.refreshIfNeeded()
        }
    }

    private func updateStatusBar() -> Void {
        guard let sensorManager = self.sensorManager else { return }

        if let selection = StatusBarDisplayPreferences.selection {
            guard let device = sensorManager.devices[selection.deviceId],
                let reading = device.reading,
                let values = StatusBarDisplayPreferences.valueStrings(for: selection, reading: reading)
            else {
                self.setStatusBarPlaceholder()
                return
            }

            self.applyStatusBarValues(values, label: self.compactStatusLabel(for: reading))
            return
        }

        guard let reading = sensorManager.sortedDevices.first(where: { $0.reading != nil })?.reading else {
            self.setStatusBarPlaceholder()
            return
        }

        self.applyStatusBarValues(StatusBarDisplayPreferences.defaultValueStrings(for: reading), label: self.compactStatusLabel(for: reading))
    }

    private func applyStatusBarTitle(_ title: String) -> Void {
        guard let statusItem = self.statusItem else { return }

        self.removeStatusItemDisplayView()
        statusItem.button?.title = title
        statusItem.button?.image = nil
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
        statusItem.button?.displayIfNeeded()
        statusItem.button?.window?.displayIfNeeded()
    }

    private func applyStatusBarValues(_ values: [String], label: String) -> Void {
        switch values.count {
            case 1, 2:
                self.applyCompactStatusBarValues(values, label: label)
            default:
                self.setStatusBarPlaceholder()
        }
    }

    private func applyCompactStatusBarValues(_ values: [String], label: String) -> Void {
        guard let statusItem = self.statusItem, let button = statusItem.button else { return }

        let displayValue = StatusItemDisplayValue(label: label, values: values)
        let width = StatusItemDisplayView.requiredWidth(for: displayValue)
        let height = button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness

        statusItem.length = width
        button.title = ""
        button.image = nil

        if self.statusItemDisplayView.superview !== button {
            self.statusItemDisplayView.removeFromSuperview()
            button.addSubview(self.statusItemDisplayView)
        }

        self.statusItemDisplayView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        self.statusItemDisplayView.autoresizingMask = [.height]
        self.statusItemDisplayView.configure(value: displayValue)
        button.needsDisplay = true
        button.displayIfNeeded()
        button.window?.displayIfNeeded()
    }

    private func compactStatusLabel(for reading: AranetReading) -> String {
        return reading.deviceType == .aranetRadiation ? "RAD" : "AIR"
    }

    private func setStatusBarPlaceholder() -> Void {
        guard let statusItem = self.statusItem else { return }

        self.removeStatusItemDisplayView()
        statusItem.button?.title = " \u{2026}"
        statusItem.button?.image = self.statusBarPlaceholderSymbol()
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
        statusItem.button?.displayIfNeeded()
        statusItem.button?.window?.displayIfNeeded()
    }

    private func removeStatusItemDisplayView() -> Void {
        self.statusItemDisplayView.removeFromSuperview()
    }

    private func statusBarPlaceholderSymbol() -> NSImage? {
        guard let image = SensorSymbol.scanningImage(pointSize: 16, weight: .semibold) else { return nil }
        image.isTemplate = true
        return image
    }
}
