import AranetKit
import Cocoa

@main class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var sensorManager: SensorManager?
    private var menuManager: MenuManager?
    private var notificationManager: NotificationManager?
    private let statusItemDisplayView = StatusItemDisplayView()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        statusItem.button?.title = " \u{2026}"
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.image = statusBarPlaceholderSymbol()
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        let menu = NSMenu()
        statusItem.menu = menu

        let sensorManager = SensorManager()
        self.sensorManager = sensorManager

        menuManager = MenuManager(menu: menu, sensorManager: sensorManager)
        notificationManager = NotificationManager(sensorManager: sensorManager)

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

    func applicationWillTerminate(_ aNotification: Notification) { sensorManager?.stopMonitoring() }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { return true }

    // MARK: - Status Bar

    @objc private func handleReadingDidUpdate() {
        MenuTrackingRefresh.perform { [weak self] in
            self?.updateStatusBar()
            self?.menuManager?.refreshIfNeeded()
        }
    }

    @objc private func handleScanStateChange() {
        if sensorManager?.isScanning == true {
            setStatusBarPlaceholder()
        }
        else if sensorManager?.sortedDevices.first(where: { $0.reading != nil }) == nil {
            setStatusBarPlaceholder()
        }
    }

    @objc private func handleStatusBarDisplayPreferenceDidChange() {
        MenuTrackingRefresh.perform { [weak self] in
            self?.updateStatusBar()
        }
    }

    private func updateStatusBar() {
        guard let sensorManager else { return }

        if let selection = StatusBarDisplayPreferences.selection {
            guard let device = sensorManager.devices[selection.deviceId],
                let reading = device.reading,
                let values = StatusBarDisplayPreferences.valueStrings(for: selection, reading: reading)
            else {
                setStatusBarPlaceholder()
                return
            }

            applyStatusBarValues(values, label: compactStatusLabel(for: reading))
            return
        }

        guard let reading = sensorManager.sortedDevices.first(where: { $0.reading != nil })?.reading else {
            setStatusBarPlaceholder()
            return
        }

        applyStatusBarValues(StatusBarDisplayPreferences.defaultValueStrings(for: reading), label: compactStatusLabel(for: reading))
    }

    private func applyStatusBarTitle(_ title: String) {
        guard let statusItem else { return }

        removeStatusItemDisplayView()
        statusItem.button?.title = title
        statusItem.button?.image = nil
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
        statusItem.button?.displayIfNeeded()
        statusItem.button?.window?.displayIfNeeded()
    }

    private func applyStatusBarValues(_ values: [String], label: String) {
        switch values.count {
            case 1, 2:
                applyCompactStatusBarValues(values, label: label)
            default:
                setStatusBarPlaceholder()
        }
    }

    private func applyCompactStatusBarValues(_ values: [String], label: String) {
        guard let statusItem, let button = statusItem.button else { return }

        let displayValue = StatusItemDisplayValue(label: label, values: values)
        let width = StatusItemDisplayView.requiredWidth(for: displayValue)
        let height = button.bounds.height > 0 ? button.bounds.height : NSStatusBar.system.thickness

        statusItem.length = width
        button.title = ""
        button.image = nil

        if statusItemDisplayView.superview !== button {
            statusItemDisplayView.removeFromSuperview()
            button.addSubview(statusItemDisplayView)
        }

        statusItemDisplayView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        statusItemDisplayView.autoresizingMask = [.height]
        statusItemDisplayView.configure(value: displayValue)
        button.needsDisplay = true
        button.displayIfNeeded()
        button.window?.displayIfNeeded()
    }

    private func compactStatusLabel(for reading: AranetReading) -> String {
        reading.deviceType == .aranetRadiation ? "RAD" : "AIR"
    }

    private func setStatusBarPlaceholder() {
        guard let statusItem else { return }

        removeStatusItemDisplayView()
        statusItem.button?.title = " \u{2026}"
        statusItem.button?.image = statusBarPlaceholderSymbol()
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
        statusItem.button?.displayIfNeeded()
        statusItem.button?.window?.displayIfNeeded()
    }

    private func removeStatusItemDisplayView() {
        statusItemDisplayView.removeFromSuperview()
    }

    private func statusBarPlaceholderSymbol() -> NSImage? {
        guard let image = SensorSymbol.scanningImage(pointSize: 16, weight: .semibold) else { return nil }
        image.isTemplate = true
        return image
    }
}
