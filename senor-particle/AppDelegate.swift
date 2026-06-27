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
                let title = selection.metric.statusItemTitle(for: reading)
            else {
                setStatusBarPlaceholder()
                return
            }

            applyStatusBarTitle(title)
            return
        }

        guard let reading = sensorManager.sortedDevices.first(where: { $0.reading != nil })?.reading,
            let metric = StatusBarDisplayMetric.defaultMetric(for: reading),
            let title = metric.statusItemTitle(for: reading)
        else {
            setStatusBarPlaceholder()
            return
        }

        applyStatusBarTitle(title)
    }

    private func applyStatusBarTitle(_ title: String) {
        guard let statusItem else { return }

        statusItem.button?.title = title
        statusItem.button?.image = nil
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
        statusItem.button?.displayIfNeeded()
        statusItem.button?.window?.displayIfNeeded()
    }

    private func setStatusBarPlaceholder() {
        guard let statusItem else { return }

        statusItem.button?.title = " \u{2026}"
        statusItem.button?.image = statusBarPlaceholderSymbol()
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.needsDisplay = true
        statusItem.button?.displayIfNeeded()
        statusItem.button?.window?.displayIfNeeded()
    }

    private func statusBarPlaceholderSymbol() -> NSImage? {
        guard let image = SensorSymbol.scanningImage(pointSize: 16, weight: .semibold) else { return nil }
        image.isTemplate = true
        return image
    }
}
