import AranetKit
import Cocoa
import ServiceManagement

// MARK: - Degraded situation preferences

enum DegradedSituationPreferences {
    static let key = "degradedSituationCycles"
    static let defaultCycles = 3
    static let minimumCycles = 1
    static let maximumCycles = 10

    static var cycles: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: key)
            if stored < minimumCycles { return defaultCycles }
            return min(stored, maximumCycles)
        }
        set {
            UserDefaults.standard.set(min(max(newValue, minimumCycles), maximumCycles), forKey: key)
        }
    }
}

// MARK: - Notification preferences

enum NotificationPreferences {
    static func isEnabled(for deviceId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "notifications.\(deviceId.uuidString)")
    }

    static func setEnabled(_ enabled: Bool, for deviceId: UUID) {
        UserDefaults.standard.set(enabled, forKey: "notifications.\(deviceId.uuidString)")
    }
}

// MARK: - Device name preferences

enum DeviceNamePreferences {
    static func name(for deviceId: UUID) -> String? {
        UserDefaults.standard.string(forKey: "deviceName.\(deviceId.uuidString)")
    }

    static func setName(_ name: String, for deviceId: UUID) {
        if name.isEmpty {
            UserDefaults.standard.removeObject(forKey: "deviceName.\(deviceId.uuidString)")
        }
        else {
            UserDefaults.standard.set(name, forKey: "deviceName.\(deviceId.uuidString)")
        }
    }
}

// MARK: - Toolbar identifiers

extension NSToolbarItem.Identifier {
    fileprivate static let general = NSToolbarItem.Identifier("general")
    fileprivate static let devices = NSToolbarItem.Identifier("devices")
    fileprivate static let advancedSettings = NSToolbarItem.Identifier("advancedSettings")
}

// MARK: - SettingsWindowController

class SettingsWindowController: NSWindowController {
    private var didCenter = false
    private let generalVC: GeneralViewController
    private let devicesVC: DevicesViewController
    private let advancedSettingsVC: AdvancedSettingsViewController
    private var selectedIdentifier = NSToolbarItem.Identifier.general

    init(sensorManager: SensorManager) {
        generalVC = GeneralViewController()
        devicesVC = DevicesViewController(sensorManager: sensorManager)
        advancedSettingsVC = AdvancedSettingsViewController()

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
    @objc private func showAdvancedSettings() { switchToTab(.advancedSettings) }

    private func switchToTab(_ identifier: NSToolbarItem.Identifier) {
        guard identifier != selectedIdentifier, let window else { return }
        selectedIdentifier = identifier
        let newVC = viewController(for: identifier)
        if let contentBounds = window.contentView?.bounds {
            _ = newVC.view  // ensure loadView has been called
            newVC.view.frame = contentBounds
        }
        window.contentViewController = newVC
        window.title = title(for: identifier)
        window.toolbar?.selectedItemIdentifier = identifier
    }

    private func viewController(for identifier: NSToolbarItem.Identifier) -> NSViewController {
        switch identifier {
            case .general: return generalVC
            case .devices: return devicesVC
            case .advancedSettings: return advancedSettingsVC
            default: return generalVC
        }
    }

    private func title(for identifier: NSToolbarItem.Identifier) -> String {
        switch identifier {
            case .general: return "General"
            case .devices: return "Devices"
            case .advancedSettings: return "Advanced"
            default: return "Settings"
        }
    }
}

// MARK: - NSToolbarDelegate

extension SettingsWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .devices, .advancedSettings]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .devices, .advancedSettings]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.general, .devices, .advancedSettings]
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
            case .advancedSettings:
                item.label = "Advanced"
                item.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Advanced")
                item.action = #selector(showAdvancedSettings)
                item.target = self
            default:
                return nil
        }
        return item
    }
}

// MARK: - GeneralViewController

class GeneralViewController: NSViewController {
    private var loginToggle: NSButton!
    private var personalityPopup: NSPopUpButton!
    private var unitSystemControl: NSSegmentedControl!
    private var timeoutLabel: NSTextField!
    private var timeoutSlider: NSSlider!

    override var preferredContentSize: NSSize {
        get { isViewLoaded ? view.bounds.size : NSSize(width: 420, height: 390) }
        set {}
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let w: CGFloat = 420
        let h: CGFloat = 390
        let x: CGFloat = 20
        let controlW = w - 2 * x
        let descriptionHeight: CGFloat = 28
        var y = h - 20 - 22

        view = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        loginToggle = NSButton(checkboxWithTitle: "Start at Login", target: self, action: #selector(toggleLogin(_:)))
        loginToggle.frame = NSRect(x: x, y: y, width: controlW, height: 22)
        loginToggle.autoresizingMask = [.minYMargin, .width]
        view.addSubview(loginToggle)

        y -= 4 + descriptionHeight
        addDescription(
            "Open Se\u{00F1}or Particle automatically after you sign in to macOS.",
            x: x,
            y: y,
            width: controlW,
            height: descriptionHeight
        )

        y -= 16 + 16
        let personalityLabel = NSTextField(labelWithString: "Notification Personality")
        personalityLabel.frame = NSRect(x: x, y: y, width: controlW, height: 16)
        personalityLabel.autoresizingMask = [.minYMargin, .width]
        view.addSubview(personalityLabel)

        y -= 4 + 26
        personalityPopup = NSPopUpButton(frame: NSRect(x: x, y: y, width: controlW, height: 26), pullsDown: false)
        personalityPopup.autoresizingMask = [.minYMargin, .width]
        for personality in NotificationPersonality.allCases {
            personalityPopup.addItem(withTitle: personality.displayName)
        }
        personalityPopup.target = self
        personalityPopup.action = #selector(personalityChanged(_:))
        view.addSubview(personalityPopup)

        y -= 4 + descriptionHeight
        addDescription(
            "Controls the tone of status notifications when sensor health changes.",
            x: x,
            y: y,
            width: controlW,
            height: descriptionHeight
        )

        y -= 16 + 16
        let unitSystemLabel = NSTextField(labelWithString: "Units")
        unitSystemLabel.frame = NSRect(x: x, y: y, width: controlW, height: 16)
        unitSystemLabel.autoresizingMask = [.minYMargin, .width]
        view.addSubview(unitSystemLabel)

        y -= 4 + 24
        unitSystemControl = NSSegmentedControl(
            labels: DisplayUnitSystem.allCases.map(\.displayName),
            trackingMode: .selectOne,
            target: self,
            action: #selector(unitSystemChanged(_:))
        )
        unitSystemControl.frame = NSRect(x: x, y: y, width: controlW, height: 24)
        unitSystemControl.autoresizingMask = [.minYMargin, .width]
        view.addSubview(unitSystemControl)

        y -= 4 + descriptionHeight
        addDescription(
            "Controls how temperature, pressure, radiation, and radon values are displayed.",
            x: x,
            y: y,
            width: controlW,
            height: descriptionHeight
        )

        y -= 16 + 16
        timeoutLabel = NSTextField(labelWithString: "")
        timeoutLabel.frame = NSRect(x: x, y: y, width: controlW, height: 16)
        timeoutLabel.autoresizingMask = [.minYMargin, .width]
        view.addSubview(timeoutLabel)

        y -= 4 + 22
        timeoutSlider = NSSlider(value: ScanPreferences.defaultTimeout, minValue: 10, maxValue: 60, target: self, action: #selector(sliderChanged(_:)))
        timeoutSlider.numberOfTickMarks = 51
        timeoutSlider.allowsTickMarkValuesOnly = true
        timeoutSlider.frame = NSRect(x: x, y: y, width: controlW, height: 22)
        timeoutSlider.autoresizingMask = [.minYMargin, .width]
        view.addSubview(timeoutSlider)

        y -= 4 + descriptionHeight
        addDescription(
            "How long a scan waits for nearby sensors before showing the results.",
            x: x,
            y: y,
            width: controlW,
            height: descriptionHeight
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        loginToggle.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let timeout = ScanPreferences.timeout
        timeoutSlider.doubleValue = timeout
        updateTimeoutLabel(seconds: timeout)

        let personality = NotificationPersonalityPreferences.current
        if let index = NotificationPersonality.allCases.firstIndex(of: personality) {
            personalityPopup.selectItem(at: index)
        }

        let unitSystem = DisplayUnitSystemPreferences.current
        if let index = DisplayUnitSystem.allCases.firstIndex(of: unitSystem) {
            unitSystemControl.selectedSegment = index
        }
    }

    // MARK: - Actions

    @objc private func personalityChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard NotificationPersonality.allCases.indices.contains(index) else { return }
        NotificationPersonalityPreferences.current = NotificationPersonality.allCases[index]
    }

    @objc private func unitSystemChanged(_ sender: NSSegmentedControl) {
        let index = sender.selectedSegment
        guard DisplayUnitSystem.allCases.indices.contains(index) else { return }
        DisplayUnitSystemPreferences.current = DisplayUnitSystem.allCases[index]
    }

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
        ScanPreferences.storedTimeout = value
        updateTimeoutLabel(seconds: value)
    }

    // MARK: - Private

    private func updateTimeoutLabel(seconds: Double) {
        timeoutLabel.stringValue = "Scan timeout: \(Int(seconds))s"
    }

    @discardableResult
    private func addDescription(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.frame = NSRect(x: x, y: y, width: width, height: height)
        field.autoresizingMask = [.minYMargin, .width]
        field.textColor = .secondaryLabelColor
        field.font = .systemFont(ofSize: 11)
        view.addSubview(field)
        return field
    }
}

// MARK: - AdvancedSettingsViewController

class AdvancedSettingsViewController: NSViewController {
    private var degradedLabel: NSTextField!
    private var degradedDescription: NSTextField!
    private var degradedSlider: NSSlider!

    override var preferredContentSize: NSSize {
        get { isViewLoaded ? view.bounds.size : NSSize(width: 420, height: 142) }
        set {}
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let w: CGFloat = 420
        let h: CGFloat = 142
        let x: CGFloat = 20
        let controlW = w - 2 * x
        var y = h - 20 - 16

        view = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        degradedLabel = NSTextField(labelWithString: "")
        degradedLabel.frame = NSRect(x: x, y: y, width: controlW, height: 16)
        degradedLabel.autoresizingMask = [.minYMargin, .width]
        view.addSubview(degradedLabel)

        y -= 4 + 22
        degradedSlider = NSSlider(
            value: Double(DegradedSituationPreferences.defaultCycles),
            minValue: Double(DegradedSituationPreferences.minimumCycles),
            maxValue: Double(DegradedSituationPreferences.maximumCycles),
            target: self,
            action: #selector(degradedSliderChanged(_:))
        )
        degradedSlider.numberOfTickMarks = DegradedSituationPreferences.maximumCycles
        degradedSlider.allowsTickMarkValuesOnly = true
        degradedSlider.frame = NSRect(x: x, y: y, width: controlW, height: 22)
        degradedSlider.autoresizingMask = [.minYMargin, .width]
        view.addSubview(degradedSlider)

        y -= 8 + 44
        degradedDescription = NSTextField(wrappingLabelWithString: "")
        degradedDescription.frame = NSRect(x: x, y: y, width: controlW, height: 44)
        degradedDescription.autoresizingMask = [.minYMargin, .width]
        degradedDescription.textColor = .secondaryLabelColor
        degradedDescription.font = .systemFont(ofSize: 11)
        degradedDescription.stringValue =
            "A degraded situation means a sensor has missed consecutive expected update cycles. At this threshold, the progress bar turns dark red to show the reading may be stale."
        view.addSubview(degradedDescription)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        let cycles = DegradedSituationPreferences.cycles
        degradedSlider.doubleValue = Double(cycles)
        updateDegradedLabel(cycles: cycles)
    }

    // MARK: - Actions

    @objc private func degradedSliderChanged(_ sender: NSSlider) {
        let cycles = Int(sender.doubleValue.rounded())
        DegradedSituationPreferences.cycles = cycles
        updateDegradedLabel(cycles: cycles)
    }

    // MARK: - Private

    private func updateDegradedLabel(cycles: Int) {
        degradedLabel.stringValue = "Degraded situation: \(cycles) missed update cycles"
    }
}

// MARK: - DevicesViewController

class DevicesViewController: NSViewController {
    private weak var sensorManager: SensorManager?
    private var outlineView: NSOutlineView!
    private var rescanButton: NSButton!
    private var deviceItems: [DeviceOutlineItem] = []
    private var metricItemsByDeviceId: [UUID: [MetricOutlineItem]] = [:]
    private var expandedDeviceIds: Set<UUID> = []
    private var didSeedExpansion = false
    private let scanningItem = ScanningOutlineItem()

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

        outlineView = NSOutlineView()
        outlineView.style = .inset
        outlineView.rowHeight = 18
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outlineView.indentationPerLevel = 14
        outlineView.dataSource = self
        outlineView.delegate = self

        let deviceCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("device"))
        deviceCol.title = "Device"
        deviceCol.width = 120
        deviceCol.minWidth = 60
        outlineView.addTableColumn(deviceCol)
        outlineView.outlineTableColumn = deviceCol

        let uuidCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("uuid"))
        uuidCol.title = "UUID"
        uuidCol.width = 200
        uuidCol.minWidth = 100
        outlineView.addTableColumn(uuidCol)

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 110
        nameCol.minWidth = 60
        outlineView.addTableColumn(nameCol)

        let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeCol.title = "Type"
        typeCol.width = 90
        typeCol.minWidth = 60
        outlineView.addTableColumn(typeCol)

        let statusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusCol.title = "Status"
        statusCol.width = 80
        statusCol.minWidth = 50
        outlineView.addTableColumn(statusCol)

        let menuBarCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("menuBar"))
        menuBarCol.title = "Menu Bar"
        menuBarCol.width = 70
        menuBarCol.minWidth = 60
        outlineView.addTableColumn(menuBarCol)

        let notifCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("notifications"))
        notifCol.title = "Notifications"
        notifCol.width = 80
        notifCol.minWidth = 60
        outlineView.addTableColumn(notifCol)

        let buttonH: CGFloat = 22
        let gap: CGFloat = 8

        rescanButton = NSButton(title: "Rescan", target: self, action: #selector(rescanDevices))
        rescanButton.bezelStyle = .rounded
        rescanButton.frame = NSRect(x: p, y: p, width: 90, height: buttonH)
        rescanButton.autoresizingMask = [.maxYMargin]
        view.addSubview(rescanButton)

        let scrollY = p + buttonH + gap
        let scrollView = NSScrollView(
            frame: NSRect(x: p, y: scrollY, width: w - 2 * p, height: h - p - scrollY))
        scrollView.documentView = outlineView
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
            selector: #selector(handleDisplayUnitSystemPreferenceDidChange),
            name: .displayUnitSystemPreferenceDidChange,
            object: nil
        )
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        reloadOutlineData()
        rescanButton.isEnabled = !(sensorManager?.isScanning ?? false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleReadingDidUpdate() {
        reloadOutlineData()
    }

    @objc private func handleScanStateChange() {
        rescanButton.isEnabled = !(sensorManager?.isScanning ?? false)
        reloadOutlineData()
    }

    @objc private func handleDisplayUnitSystemPreferenceDidChange() {
        reloadOutlineData()
    }

    @objc private func rescanDevices() {
        sensorManager?.rescan()
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

    private func reloadOutlineData() {
        if didSeedExpansion {
            expandedDeviceIds = currentExpandedDeviceIds()
        }

        rebuildOutlineItems()
        outlineView.reloadData()

        if didSeedExpansion == false {
            expandedDeviceIds = Set(deviceItems.map(\.deviceId))
            didSeedExpansion = true
        }

        for item in deviceItems where expandedDeviceIds.contains(item.deviceId) {
            outlineView.expandItem(item)
        }
    }

    private func rebuildOutlineItems() {
        guard let sensorManager, sensorManager.isScanning == false else {
            deviceItems.removeAll()
            metricItemsByDeviceId.removeAll()
            return
        }

        let devices = sensorManager.sortedDevices
        deviceItems = devices.map { DeviceOutlineItem(deviceId: $0.device.id) }
        metricItemsByDeviceId = Dictionary(
            uniqueKeysWithValues: devices.map { device in
                let metrics = StatusBarDisplayMetric.availableMetrics(for: device.reading).map {
                    MetricOutlineItem(deviceId: device.device.id, metric: $0)
                }
                return (device.device.id, metrics)
            }
        )
    }

    private func currentExpandedDeviceIds() -> Set<UUID> {
        Set(deviceItems.compactMap { outlineView.isItemExpanded($0) ? $0.deviceId : nil })
    }

    private func device(for item: DeviceOutlineItem) -> MonitoredDevice? {
        sensorManager?.devices[item.deviceId]
    }

    private func device(for item: MetricOutlineItem) -> MonitoredDevice? {
        sensorManager?.devices[item.deviceId]
    }

    private func isMenuBarMetricSelected(_ item: MetricOutlineItem) -> Bool {
        StatusBarDisplayPreferences.isSelected(deviceId: item.deviceId, metric: item.metric)
    }

    private func canSelectMenuBarMetric(_ item: MetricOutlineItem) -> Bool {
        StatusBarDisplayPreferences.canSelect(deviceId: item.deviceId, metric: item.metric)
    }
}

// MARK: - DeviceNameTextField

private class DeviceNameTextField: NSTextField {
    var deviceId: UUID?
}

// MARK: - Outline items

private final class ScanningOutlineItem {}

private final class DeviceOutlineItem {
    let deviceId: UUID

    init(deviceId: UUID) {
        self.deviceId = deviceId
    }
}

private final class MetricOutlineItem {
    let deviceId: UUID
    let metric: StatusBarDisplayMetric

    init(deviceId: UUID, metric: StatusBarDisplayMetric) {
        self.deviceId = deviceId
        self.metric = metric
    }
}

// MARK: - NSOutlineViewDataSource

extension DevicesViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let sensorManager else { return 0 }
        if sensorManager.isScanning {
            return item == nil ? 1 : 0
        }
        if let deviceItem = item as? DeviceOutlineItem {
            return metricItemsByDeviceId[deviceItem.deviceId]?.count ?? 0
        }
        return item == nil ? deviceItems.count : 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let sensorManager else { return scanningItem }

        if sensorManager.isScanning {
            return scanningItem
        }
        if let deviceItem = item as? DeviceOutlineItem,
            let metricItems = metricItemsByDeviceId[deviceItem.deviceId],
            metricItems.indices.contains(index)
        {
            return metricItems[index]
        }

        return deviceItems[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let deviceItem = item as? DeviceOutlineItem else { return false }
        return metricItemsByDeviceId[deviceItem.deviceId]?.isEmpty == false
    }
}

// MARK: - NSOutlineViewDelegate

extension DevicesViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        !(item is ScanningOutlineItem)
    }

    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        item is DeviceOutlineItem
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] as? DeviceOutlineItem else { return }
        expandedDeviceIds.insert(item.deviceId)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] as? DeviceOutlineItem else { return }
        expandedDeviceIds.remove(item.deviceId)
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let colId = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        if item is ScanningOutlineItem {
            guard colId.rawValue == "device" else { return nil }
            let cell = textCell(identifier: "cell-scanning", in: outlineView)
            cell.stringValue = "Scanning for devices\u{2026}"
            cell.textColor = .secondaryLabelColor
            return cell
        }

        if let metricItem = item as? MetricOutlineItem {
            return view(for: metricItem, columnId: colId, in: outlineView)
        }

        guard let deviceItem = item as? DeviceOutlineItem,
            let device = device(for: deviceItem)
        else { return nil }

        if colId.rawValue == "notifications" {
            let btn = checkboxCell(
                identifier: "cell-notifications", action: #selector(notificationToggleChanged(_:)), in: outlineView)
            btn.state = NotificationPreferences.isEnabled(for: device.device.id) ? .on : .off
            return btn
        }

        if colId.rawValue == "menuBar" {
            return nil
        }

        if colId.rawValue == "name" {
            let cellId = NSUserInterfaceItemIdentifier("cell-name")
            let field: DeviceNameTextField
            if let existing = outlineView.makeView(withIdentifier: cellId, owner: nil) as? DeviceNameTextField {
                field = existing
            }
            else {
                field = DeviceNameTextField()
                field.identifier = cellId
                field.isBordered = false
                field.drawsBackground = false
                field.lineBreakMode = .byTruncatingTail
                field.font = .systemFont(ofSize: 11)
                field.delegate = self
            }
            field.deviceId = device.device.id
            field.stringValue = DeviceNamePreferences.name(for: device.device.id) ?? ""
            field.placeholderString = device.reading?.name ?? device.device.name
            return field
        }

        let cell = textCell(identifier: "cell-\(colId.rawValue)", in: outlineView)

        switch colId.rawValue {
            case "device":
                cell.stringValue = device.reading?.name ?? device.device.name
                cell.textColor = .labelColor
            case "uuid":
                cell.stringValue = device.device.id.uuidString
                cell.textColor = .secondaryLabelColor
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

    private func view(
        for item: MetricOutlineItem, columnId: NSUserInterfaceItemIdentifier, in outlineView: NSOutlineView
    )
        -> NSView?
    {
        switch columnId.rawValue {
            case "device":
                let cell = textCell(identifier: "cell-metric-device", in: outlineView)
                cell.stringValue = item.metric.label
                cell.textColor = .labelColor
                return cell
            case "status":
                let cell = textCell(identifier: "cell-metric-status", in: outlineView)
                if let reading = device(for: item)?.reading,
                    let value = item.metric.valueString(for: reading)
                {
                    cell.stringValue = value
                    cell.textColor = .labelColor
                }
                else {
                    cell.stringValue = "\u{2014}"
                    cell.textColor = .secondaryLabelColor
                }
                return cell
            case "menuBar":
                let btn = checkboxCell(
                    identifier: "cell-menu-bar", action: #selector(menuBarMetricChanged(_:)), in: outlineView)
                btn.state = isMenuBarMetricSelected(item) ? .on : .off
                btn.isEnabled = canSelectMenuBarMetric(item)
                return btn
            default:
                return nil
        }
    }

    private func textCell(identifier: String, in outlineView: NSOutlineView) -> NSTextField {
        let cellId = NSUserInterfaceItemIdentifier(identifier)
        if let existing = outlineView.makeView(withIdentifier: cellId, owner: nil) as? NSTextField {
            return existing
        }

        let cell = NSTextField(labelWithString: "")
        cell.identifier = cellId
        cell.lineBreakMode = .byTruncatingTail
        cell.font = .systemFont(ofSize: 11)
        return cell
    }

    private func checkboxCell(identifier: String, action: Selector, in outlineView: NSOutlineView) -> NSButton {
        let cellId = NSUserInterfaceItemIdentifier(identifier)
        if let existing = outlineView.makeView(withIdentifier: cellId, owner: nil) as? NSButton {
            return existing
        }

        let btn = NSButton(checkboxWithTitle: "", target: self, action: action)
        btn.identifier = cellId
        return btn
    }

    @objc private func notificationToggleChanged(_ sender: NSButton) {
        let row = outlineView.row(for: sender)
        guard row >= 0,
            let item = outlineView.item(atRow: row) as? DeviceOutlineItem
        else { return }
        NotificationPreferences.setEnabled(sender.state == .on, for: item.deviceId)
    }

    @objc private func menuBarMetricChanged(_ sender: NSButton) {
        let row = outlineView.row(for: sender)
        guard row >= 0,
            let item = outlineView.item(atRow: row) as? MetricOutlineItem
        else { return }

        StatusBarDisplayPreferences.toggleSelection(deviceId: item.deviceId, metric: item.metric)
        reloadOutlineData()
    }
}

// MARK: - NSTextFieldDelegate

extension DevicesViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? DeviceNameTextField,
            let deviceId = field.deviceId
        else { return }
        DeviceNamePreferences.setName(field.stringValue, for: deviceId)
    }
}
