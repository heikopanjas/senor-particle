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

        statusItem.button?.title = " n/a"
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.image = NSImage(systemSymbolName: "aqi.medium", accessibilityDescription: "senor-particle")?.withSymbolConfiguration(
            .init(pointSize: 13, weight: .black))
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        let menu = NSMenu()
        statusItem.menu = menu

        let sensorManager = SensorManager()
        self.sensorManager = sensorManager

        sensorManager.onUpdate = { [weak self] in
            self?.updateStatusBar()
            self?.menuManager?.refreshIfNeeded()
        }

        menuManager = MenuManager(menu: menu, sensorManager: sensorManager)
        notificationManager = NotificationManager(sensorManager: sensorManager)

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
            }
            catch { print("Scan failed: \(error)") }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) { sensorManager?.stopMonitoring() }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { return true }

    // MARK: - Status Bar

    @objc private func handleScanStateChange() {
        if sensorManager?.isScanning == true {
            statusItem?.button?.title = " \u{2026}"
        }
        else if sensorManager?.sortedDevices.first(where: { $0.reading != nil }) == nil {
            statusItem?.button?.title = " n/a"
        }
    }

    private func updateStatusBar() {
        guard let reading = sensorManager?.sortedDevices.first(where: { $0.reading != nil })?.reading else { return }

        if let co2 = reading.co2 {
            statusItem?.button?.title = " \(co2) ppm"
        }
        else if let rate = reading.radiationRate {
            let uSv = rate.converted(to: .microsieverts)
            statusItem?.button?.title = String(format: " %.3f \u{00B5}Sv/h", uSv.value)
        }
        else if let temp = reading.temperature {
            statusItem?.button?.title = String(format: " %.1f\u{00B0}C", temp.value)
        }
    }
}
