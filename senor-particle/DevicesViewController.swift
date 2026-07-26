import AranetKit
import Cocoa

class DevicesViewController: NSViewController {
    private weak var sensorManager: SensorManager?
    private let outlineView = NSOutlineView()
    private let rescanButton = NSButton(title: "Rescan", target: nil, action: nil)
    private var deviceItems: [DeviceOutlineItem] = []
    private var metricItemsByDeviceId: [UUID: [MetricOutlineItem]] = [:]
    private var expandedDeviceIds: Set<UUID> = []
    private var didSeedExpansion = false
    private let scanningItem = ScanningOutlineItem()

    override var preferredContentSize: NSSize {
        get { return self.isViewLoaded ? self.view.bounds.size : NSSize(width: 420, height: 300) }
        set {}
    }

    init(sensorManager: SensorManager) {
        self.sensorManager = sensorManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() -> Void {
        let padding: CGFloat = 16
        let width: CGFloat = 420
        let height: CGFloat = 300

        self.view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        self.outlineView.style = .inset
        self.outlineView.rowHeight = 18
        self.outlineView.usesAlternatingRowBackgroundColors = true
        self.outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        self.outlineView.indentationPerLevel = 14
        self.outlineView.dataSource = self
        self.outlineView.delegate = self

        self.addColumn(identifier: "device", title: "Device", width: 120, minWidth: 60)
        self.outlineView.outlineTableColumn = self.outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("device"))
        self.addColumn(identifier: "uuid", title: "UUID", width: 200, minWidth: 100)
        self.addColumn(identifier: "name", title: "Name", width: 110, minWidth: 60)
        self.addColumn(identifier: "type", title: "Type", width: 90, minWidth: 60)
        self.addColumn(identifier: "status", title: "Status", width: 80, minWidth: 50)
        self.addColumn(identifier: "menuBar", title: "Menu Bar", width: 70, minWidth: 60)
        self.addColumn(identifier: "notifications", title: "Notifications", width: 80, minWidth: 60)

        let buttonHeight: CGFloat = 22
        let gap: CGFloat = 8

        self.rescanButton.target = self
        self.rescanButton.action = #selector(self.rescanDevices)
        self.rescanButton.bezelStyle = .rounded
        self.rescanButton.frame = NSRect(x: padding, y: padding, width: 90, height: buttonHeight)
        self.rescanButton.autoresizingMask = [.maxYMargin]
        self.view.addSubview(self.rescanButton)

        let scrollY = padding + buttonHeight + gap
        let scrollView = NSScrollView(frame: NSRect(x: padding, y: scrollY, width: width - 2 * padding, height: height - padding - scrollY))
        scrollView.documentView = self.outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]
        self.view.addSubview(scrollView)
    }

    override func viewDidLoad() -> Void {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleReadingDidUpdate),
            name: .aranetReadingDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleScanStateChange),
            name: .aranetScanStateDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleDisplayUnitSystemPreferenceDidChange),
            name: .displayUnitSystemPreferenceDidChange,
            object: nil
        )
    }

    override func viewWillAppear() -> Void {
        super.viewWillAppear()
        self.reloadOutlineData()
        self.rescanButton.isEnabled = (self.sensorManager?.isScanning ?? false) == false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleReadingDidUpdate() -> Void {
        self.reloadOutlineData()
    }

    @objc private func handleScanStateChange() -> Void {
        self.rescanButton.isEnabled = (self.sensorManager?.isScanning ?? false) == false
        self.reloadOutlineData()
    }

    @objc private func handleDisplayUnitSystemPreferenceDidChange() -> Void {
        self.reloadOutlineData()
    }

    @objc private func rescanDevices() -> Void {
        self.sensorManager?.rescan()
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private func statusString(for device: MonitoredDevice) -> String {
        guard device.reading != nil, let date = device.lastUpdated else { return "Searching\u{2026}" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func reloadOutlineData() -> Void {
        if self.didSeedExpansion == true {
            self.expandedDeviceIds = self.currentExpandedDeviceIds()
        }

        self.rebuildOutlineItems()
        self.outlineView.reloadData()

        if self.didSeedExpansion == false {
            self.expandedDeviceIds = Set(self.deviceItems.map(\.deviceId))
            self.didSeedExpansion = true
        }

        for item in self.deviceItems where self.expandedDeviceIds.contains(item.deviceId) == true {
            self.outlineView.expandItem(item)
        }
    }

    private func rebuildOutlineItems() -> Void {
        guard let sensorManager = self.sensorManager, sensorManager.isScanning == false else {
            self.deviceItems.removeAll()
            self.metricItemsByDeviceId.removeAll()
            return
        }

        let devices = sensorManager.sortedDevices
        self.deviceItems = devices.map { DeviceOutlineItem(deviceId: $0.device.id) }
        self.metricItemsByDeviceId = Dictionary(
            uniqueKeysWithValues: devices.map { device in
                let metrics = StatusBarDisplayMetric.availableMetrics(for: device.reading).map {
                    MetricOutlineItem(deviceId: device.device.id, metric: $0)
                }
                return (device.device.id, metrics)
            }
        )
    }

    private func currentExpandedDeviceIds() -> Set<UUID> {
        return Set(self.deviceItems.compactMap { self.outlineView.isItemExpanded($0) == true ? $0.deviceId : nil })
    }

    private func device(for item: DeviceOutlineItem) -> MonitoredDevice? {
        return self.sensorManager?.devices[item.deviceId]
    }

    private func device(for item: MetricOutlineItem) -> MonitoredDevice? {
        return self.sensorManager?.devices[item.deviceId]
    }

    private func isMenuBarMetricSelected(_ item: MetricOutlineItem) -> Bool {
        return StatusBarDisplayPreferences.isSelected(deviceId: item.deviceId, metric: item.metric)
    }

    private func canSelectMenuBarMetric(_ item: MetricOutlineItem) -> Bool {
        return StatusBarDisplayPreferences.canSelect(deviceId: item.deviceId, metric: item.metric)
    }

    private func addColumn(identifier: String, title: String, width: CGFloat, minWidth: CGFloat) -> Void {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        column.minWidth = minWidth
        self.outlineView.addTableColumn(column)
    }
}

private class DeviceNameTextField: NSTextField {
    var deviceId: UUID?
}

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

extension DevicesViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let sensorManager = self.sensorManager else { return 0 }
        if sensorManager.isScanning == true {
            return item == nil ? 1 : 0
        }
        if let deviceItem = item as? DeviceOutlineItem {
            return self.metricItemsByDeviceId[deviceItem.deviceId]?.count ?? 0
        }
        return item == nil ? self.deviceItems.count : 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let sensorManager = self.sensorManager else { return self.scanningItem }

        if sensorManager.isScanning == true {
            return self.scanningItem
        }
        if let deviceItem = item as? DeviceOutlineItem,
            let metricItems = self.metricItemsByDeviceId[deviceItem.deviceId],
            metricItems.indices.contains(index) == true
        {
            return metricItems[index]
        }

        return self.deviceItems[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let deviceItem = item as? DeviceOutlineItem else { return false }
        return self.metricItemsByDeviceId[deviceItem.deviceId]?.isEmpty == false
    }
}

extension DevicesViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return (item is ScanningOutlineItem) == false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        return item is DeviceOutlineItem
    }

    func outlineViewItemDidExpand(_ notification: Notification) -> Void {
        guard let item = notification.userInfo?["NSObject"] as? DeviceOutlineItem else { return }
        self.expandedDeviceIds.insert(item.deviceId)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) -> Void {
        guard let item = notification.userInfo?["NSObject"] as? DeviceOutlineItem else { return }
        self.expandedDeviceIds.remove(item.deviceId)
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let columnId = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")

        if item is ScanningOutlineItem {
            guard columnId.rawValue == "device" else { return nil }
            let cell = self.textCell(identifier: "cell-scanning", in: outlineView)
            cell.stringValue = "Scanning for devices\u{2026}"
            cell.textColor = .secondaryLabelColor
            return cell
        }

        if let metricItem = item as? MetricOutlineItem {
            return self.view(for: metricItem, columnId: columnId, in: outlineView)
        }

        guard let deviceItem = item as? DeviceOutlineItem,
            let device = self.device(for: deviceItem)
        else { return nil }

        if columnId.rawValue == "notifications" {
            let button = self.checkboxCell(identifier: "cell-notifications", action: #selector(self.notificationToggleChanged(_:)), in: outlineView)
            button.state = NotificationPreferences.isEnabled(for: device.device.id) ? .on : .off
            return button
        }

        if columnId.rawValue == "menuBar" {
            return nil
        }

        if columnId.rawValue == "name" {
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

        let cell = self.textCell(identifier: "cell-\(columnId.rawValue)", in: outlineView)

        switch columnId.rawValue {
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
                cell.stringValue = self.statusString(for: device)
                cell.textColor = device.reading != nil ? .labelColor : .secondaryLabelColor
            default:
                break
        }
        return cell
    }

    private func view(for item: MetricOutlineItem, columnId: NSUserInterfaceItemIdentifier, in outlineView: NSOutlineView) -> NSView? {
        switch columnId.rawValue {
            case "device":
                let cell = self.textCell(identifier: "cell-metric-device", in: outlineView)
                cell.stringValue = item.metric.label
                cell.textColor = .labelColor
                return cell
            case "status":
                let cell = self.textCell(identifier: "cell-metric-status", in: outlineView)
                if let reading = self.device(for: item)?.reading,
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
                let button = self.checkboxCell(identifier: "cell-menu-bar", action: #selector(self.menuBarMetricChanged(_:)), in: outlineView)
                button.state = self.isMenuBarMetricSelected(item) ? .on : .off
                button.isEnabled = self.canSelectMenuBarMetric(item)
                return button
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

        let button = NSButton(checkboxWithTitle: "", target: self, action: action)
        button.identifier = cellId
        return button
    }

    @objc private func notificationToggleChanged(_ sender: NSButton) -> Void {
        let row = self.outlineView.row(for: sender)
        guard row >= 0,
            let item = self.outlineView.item(atRow: row) as? DeviceOutlineItem
        else { return }
        NotificationPreferences.setEnabled(sender.state == .on, for: item.deviceId)
    }

    @objc private func menuBarMetricChanged(_ sender: NSButton) -> Void {
        let row = self.outlineView.row(for: sender)
        guard row >= 0,
            let item = self.outlineView.item(atRow: row) as? MetricOutlineItem
        else { return }

        StatusBarDisplayPreferences.toggleSelection(deviceId: item.deviceId, metric: item.metric)
        self.reloadOutlineData()
    }
}

extension DevicesViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) -> Void {
        guard let field = obj.object as? DeviceNameTextField,
            let deviceId = field.deviceId
        else { return }
        DeviceNamePreferences.setName(field.stringValue, for: deviceId)
    }
}
