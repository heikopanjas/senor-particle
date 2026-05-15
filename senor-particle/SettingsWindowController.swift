import AranetKit
import Cocoa
import ServiceManagement

// MARK: - Notification preferences

enum NotificationPreferences {
    static func isEnabled(for deviceId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "notifications.\(deviceId.uuidString)")
    }

    static func setEnabled(_ enabled: Bool, for deviceId: UUID) {
        UserDefaults.standard.set(enabled, forKey: "notifications.\(deviceId.uuidString)")
    }
}

// MARK: - Toolbar identifiers

extension NSToolbarItem.Identifier {
    fileprivate static let general = NSToolbarItem.Identifier("general")
    fileprivate static let devices = NSToolbarItem.Identifier("devices")
}

// MARK: - SettingsWindowController

class SettingsWindowController: NSWindowController {
    private var didCenter = false
    private let generalVC: GeneralViewController
    private let devicesVC: DevicesViewController
    private var selectedIdentifier = NSToolbarItem.Identifier.general

    init(sensorManager: SensorManager) {
        generalVC = GeneralViewController(sensorManager: sensorManager)
        devicesVC = DevicesViewController(sensorManager: sensorManager)

        super.init(
            window: NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 72),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            ))

        guard let window else { return }
        window.title = "General"
        window.toolbarStyle = .preference
        window.contentViewController = generalVC

        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.delegate = self
        window.toolbar = toolbar
        toolbar.selectedItemIdentifier = .general
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showAndBringToFront() {
        if !didCenter, let window, let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let w = (sf.width / 2).rounded()
            let h = (sf.height / 2).rounded()
            let x = (sf.midX - w / 2).rounded()
            let y = (sf.midY - h / 2).rounded()
            window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
            didCenter = true
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Tab switching

    @objc private func showGeneral() { switchToTab(.general) }
    @objc private func showDevices() { switchToTab(.devices) }

    private func switchToTab(_ identifier: NSToolbarItem.Identifier) {
        guard identifier != selectedIdentifier, let window else { return }
        selectedIdentifier = identifier
        let newVC: NSViewController = identifier == .general ? generalVC : devicesVC
        if let contentBounds = window.contentView?.bounds {
            _ = newVC.view  // ensure loadView has been called
            newVC.view.frame = contentBounds
        }
        window.contentViewController = newVC
        window.title = identifier == .general ? "General" : "Devices"
        window.toolbar?.selectedItemIdentifier = identifier
    }
}

// MARK: - NSToolbarDelegate

extension SettingsWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .devices]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .devices]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .devices]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
            case .general:
                item.label = "General"
                item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
                item.action = #selector(showGeneral)
                item.target = self
            case .devices:
                item.label = "Devices"
                item.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Devices")
                item.action = #selector(showDevices)
                item.target = self
            default:
                return nil
        }
        return item
    }
}

// MARK: - GeneralViewController

class GeneralViewController: NSViewController {
    private weak var sensorManager: SensorManager?
    private var loginToggle: NSButton!
    private var timeoutLabel: NSTextField!
    private var timeoutSlider: NSSlider!
    private var rescanButton: NSButton!

    private let defaultTimeout: Double = 15

    override var preferredContentSize: NSSize {
        get { isViewLoaded ? view.bounds.size : NSSize(width: 420, height: 300) }
        set {}
    }

    init(sensorManager: SensorManager) {
        self.sensorManager = sensorManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let w: CGFloat = 420
        let h: CGFloat = 300
        let x: CGFloat = 20
        let controlW = w - 2 * x
        var y = h - 20 - 22

        view = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        loginToggle = NSButton(checkboxWithTitle: "Start at Login", target: self, action: #selector(toggleLogin(_:)))
        loginToggle.frame = NSRect(x: x, y: y, width: controlW, height: 22)
        loginToggle.autoresizingMask = [.minYMargin, .width]
        view.addSubview(loginToggle)

        y -= 16 + 16
        timeoutLabel = NSTextField(labelWithString: "")
        timeoutLabel.frame = NSRect(x: x, y: y, width: controlW, height: 16)
        timeoutLabel.autoresizingMask = [.minYMargin, .width]
        view.addSubview(timeoutLabel)

        y -= 4 + 22
        timeoutSlider = NSSlider(value: defaultTimeout, minValue: 10, maxValue: 60, target: self, action: #selector(sliderChanged(_:)))
        timeoutSlider.numberOfTickMarks = 51
        timeoutSlider.allowsTickMarkValuesOnly = true
        timeoutSlider.frame = NSRect(x: x, y: y, width: controlW, height: 22)
        timeoutSlider.autoresizingMask = [.minYMargin, .width]
        view.addSubview(timeoutSlider)

        y -= 16 + 22
        rescanButton = NSButton(title: "Rescan", target: self, action: #selector(rescanDevices))
        rescanButton.bezelStyle = .rounded
        rescanButton.frame = NSRect(x: x, y: y, width: 90, height: 22)
        rescanButton.autoresizingMask = [.minYMargin]
        view.addSubview(rescanButton)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScanStateChange),
            name: .aranetScanStateDidChange,
            object: nil
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loginToggle.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let stored = UserDefaults.standard.double(forKey: "scanTimeout")
        let timeout = stored > 0 ? stored : defaultTimeout
        timeoutSlider.doubleValue = timeout
        updateTimeoutLabel(seconds: timeout)

        rescanButton.isEnabled = !(sensorManager?.isScanning ?? false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions

    @objc private func toggleLogin(_ sender: NSButton) {
        let enable = sender.state == .on
        do {
            if enable {
                try SMAppService.mainApp.register()
            }
            else {
                try SMAppService.mainApp.unregister()
            }
        }
        catch {
            NSLog("[Settings] Start at Login toggle failed: %@", error.localizedDescription)
            loginToggle.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        UserDefaults.standard.set(value, forKey: "scanTimeout")
        updateTimeoutLabel(seconds: value)
    }

    @objc private func rescanDevices() {
        sensorManager?.rescan()
    }

    @objc private func handleScanStateChange() {
        rescanButton.isEnabled = !(sensorManager?.isScanning ?? false)
    }

    // MARK: - Private

    private func updateTimeoutLabel(seconds: Double) {
        timeoutLabel.stringValue = "Scan timeout: \(Int(seconds))s"
    }
}

// MARK: - DevicesViewController

class DevicesViewController: NSViewController {
    private weak var sensorManager: SensorManager?
    private var tableView: NSTableView!

    override var preferredContentSize: NSSize {
        get { isViewLoaded ? view.bounds.size : NSSize(width: 420, height: 300) }
        set {}
    }

    init(sensorManager: SensorManager) {
        self.sensorManager = sensorManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let p: CGFloat = 16
        let w: CGFloat = 420
        let h: CGFloat = 300

        view = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        tableView = NSTableView()
        tableView.style = .inset
        tableView.rowHeight = 18
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.dataSource = self
        tableView.delegate = self

        let deviceCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("device"))
        deviceCol.title = "Device"
        deviceCol.width = 160
        deviceCol.minWidth = 80
        tableView.addTableColumn(deviceCol)

        let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeCol.title = "Type"
        typeCol.width = 120
        typeCol.minWidth = 80
        tableView.addTableColumn(typeCol)

        let statusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusCol.title = "Status"
        statusCol.width = 100
        statusCol.minWidth = 60
        tableView.addTableColumn(statusCol)

        let notifCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("notifications"))
        notifCol.title = "Notifications"
        notifCol.width = 100
        notifCol.minWidth = 70
        tableView.addTableColumn(notifCol)

        let scrollView = NSScrollView(frame: NSRect(x: p, y: p, width: w - 2 * p, height: h - 2 * p))
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]
        view.addSubview(scrollView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSensorUpdate),
            name: .aranetSensorDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSensorUpdate),
            name: .aranetScanStateDidChange,
            object: nil
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleSensorUpdate() {
        tableView.reloadData()
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private func statusString(for device: MonitoredDevice) -> String {
        guard device.reading != nil, let date = device.lastUpdated else { return "Searching\u{2026}" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - NSTableViewDataSource

extension DevicesViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let sensorManager else { return 0 }
        return sensorManager.isScanning ? 1 : sensorManager.sortedDevices.count
    }
}

// MARK: - NSTableViewDelegate

extension DevicesViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return !(sensorManager?.isScanning ?? false)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let sensorManager else { return nil }

        if sensorManager.isScanning {
            guard tableColumn?.identifier.rawValue == "device" else { return nil }
            let cellId = NSUserInterfaceItemIdentifier("cell-scanning")
            let cell: NSTextField
            if let existing = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTextField {
                cell = existing
            }
            else {
                cell = NSTextField(labelWithString: "")
                cell.identifier = cellId
                cell.font = .systemFont(ofSize: 11)
                cell.textColor = .secondaryLabelColor
            }
            cell.stringValue = "Scanning for devices\u{2026}"
            return cell
        }

        let devices = sensorManager.sortedDevices
        guard row < devices.count else { return nil }
        let device = devices[row]
        let colId = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        if colId.rawValue == "notifications" {
            let cellId = NSUserInterfaceItemIdentifier("cell-notifications")
            let btn: NSButton
            if let existing = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSButton {
                btn = existing
            }
            else {
                btn = NSButton()
                btn.identifier = cellId
                btn.setButtonType(.switch)
                btn.title = ""
                btn.target = self
                btn.action = #selector(notificationToggleChanged(_:))
            }
            btn.state = NotificationPreferences.isEnabled(for: device.device.id) ? .on : .off
            return btn
        }

        let cellId = NSUserInterfaceItemIdentifier("cell-\(colId.rawValue)")
        let cell: NSTextField
        if let existing = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTextField {
            cell = existing
        }
        else {
            cell = NSTextField(labelWithString: "")
            cell.identifier = cellId
            cell.lineBreakMode = .byTruncatingTail
            cell.font = .systemFont(ofSize: 11)
        }

        switch colId.rawValue {
            case "device":
                cell.stringValue = device.reading?.name ?? device.device.name
                cell.textColor = .labelColor
            case "type":
                cell.stringValue = device.reading?.deviceType.name ?? "\u{2014}"
                cell.textColor = device.reading != nil ? .labelColor : .secondaryLabelColor
            case "status":
                cell.stringValue = statusString(for: device)
                cell.textColor = device.reading != nil ? .labelColor : .secondaryLabelColor
            default:
                break
        }
        return cell
    }

    @objc private func notificationToggleChanged(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0, let devices = sensorManager?.sortedDevices, row < devices.count else { return }
        NotificationPreferences.setEnabled(sender.state == .on, for: devices[row].device.id)
    }
}
