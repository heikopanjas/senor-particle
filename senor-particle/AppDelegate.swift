import AranetKit
import Cocoa

@main class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var sensorManager: SensorManager?
    private var menuManager: MenuManager?
    private var notificationManager: NotificationManager?

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

        Task {
            do {
                try await sensorManager.scan()
                sensorManager.startMonitoring()
                MenuTrackingRefresh.perform { [weak self] in
                    self?.updateStatusBar()
                    self?.menuManager?.refreshIfNeeded()
                }
            }
            catch { print("Scan failed: \(error)") }
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
            statusItem?.button?.title = " \u{2026}"
            statusItem?.button?.image = statusBarPlaceholderSymbol()
        }
        else if sensorManager?.sortedDevices.first(where: { $0.reading != nil }) == nil {
            statusItem?.button?.title = " \u{2026}"
            statusItem?.button?.image = statusBarPlaceholderSymbol()
        }
    }

    private func updateStatusBar() {
        guard let statusItem,
            let reading = sensorManager?.sortedDevices.first(where: { $0.reading != nil })?.reading
        else { return }

        let title: String
        if let co2 = reading.co2 {
            title = " \(co2) ppm"
        }
        else if let rate = reading.radiationRate {
            let uSv = rate.converted(to: .microsieverts)
            title = String(format: " %.3f \u{00B5}Sv/h", uSv.value)
        }
        else if let temp = reading.temperature {
            title = String(format: " %.1f\u{00B0}C", temp.value)
        }
        else {
            return
        }

        statusItem.button?.title = title
        statusItem.button?.image = statusBarSymbol(for: reading)
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
        statusItem.button?.displayIfNeeded()
        statusItem.button?.window?.displayIfNeeded()
    }

    private func statusBarSymbol(for reading: AranetReading?) -> NSImage? {
        guard let reading else {
            return statusBarPlaceholderSymbol()
        }

        let status = SensorSymbol.effectiveStatus(from: reading)
        return SensorSymbol.image(for: reading.deviceType, status: status, pointSize: 13, weight: .black)
    }

    private func statusBarPlaceholderSymbol() -> NSImage? {
        guard let image = SensorSymbol.scanningImage(pointSize: 16, weight: .semibold) else { return nil }
        image.isTemplate = true
        return image
    }
}
