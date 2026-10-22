import AranetKit
import Cocoa

/// Settings > Devices: every device with its custom name, status, and notification toggle, and below each device the
/// metrics that can be pinned to the menu bar.
final class DevicesViewController: NSViewController {
    private enum DeviceColumn: String, CaseIterable {
        case device
        case uuid
        case name
        case type
        case status
        case menuBar
        case notifications

        struct Layout {
            let title: String
            let width: CGFloat
            let minWidth: CGFloat
        }

        var identifier: NSUserInterfaceItemIdentifier {
            return NSUserInterfaceItemIdentifier(self.rawValue)
        }

        var layout: Layout {
            switch self {
                case .device:
                    return Layout(title: "Device", width: 120, minWidth: 60)
                case .uuid:
                    return Layout(title: "UUID", width: 200, minWidth: 100)
                case .name:
                    return Layout(title: "Name", width: 110, minWidth: 60)
                case .type:
                    return Layout(title: "Type", width: 90, minWidth: 60)
                case .status:
                    return Layout(title: "Status", width: 80, minWidth: 50)
                case .menuBar:
                    return Layout(title: "Menu Bar", width: 70, minWidth: 60)
                case .notifications:
                    return Layout(title: "Notifications", width: 80, minWidth: 60)
            }
        }

        /// The reuse identifier of this column's cell in device rows, or in metric rows when `isMetricRow` is true.
        func cellIdentifier(isMetricRow: Bool) -> NSUserInterfaceItemIdentifier {
            let prefix = isMetricRow == true ? "cell-metric-" : "cell-"
            return NSUserInterfaceItemIdentifier(prefix + self.rawValue)
        }
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

    private static let designSize = NSSize(width: 420, height: 300)
    private static let padding: CGFloat = 16
    private static let buttonSize = NSSize(width: 90, height: 22)
    private static let gap: CGFloat = 8
    private static let rowHeight: CGFloat = 18
    private static let indentation: CGFloat = 14
    private static let cellFontSize: CGFloat = 11
    private static let scanningCellIdentifier = NSUserInterfaceItemIdentifier("cell-scanning")

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private weak var sensorManager: SensorManager?
    private let preferences: PreferencesStore
    private let now: () -> Date
    private let outlineView = NSOutlineView()
    private let rescanButton = NSButton(title: "Rescan", target: nil, action: nil)
    private let notificationsDeniedLabel = NSTextField(
        labelWithString: "Notifications are turned off for \(Bundle.main.displayName) in System Settings."
    )
    private var deviceItems: [DeviceOutlineItem] = []
    private var metricItemsByDeviceId: [UUID: [MetricOutlineItem]] = [:]
    private var expandedDeviceIds: Set<UUID> = []
    private var didSeedExpansion = false
    private let scanningItem = ScanningOutlineItem()

    override var preferredContentSize: NSSize {
        get { return self.isViewLoaded == true ? self.view.bounds.size : Self.designSize }
        set {}
    }

    init(sensorManager: SensorManager, preferences: PreferencesStore, now: @escaping () -> Date = { Date() }) {
        self.sensorManager = sensorManager
        self.preferences = preferences
        self.now = now
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() -> Void {
        let size = Self.designSize
        self.view = NSView(frame: NSRect(origin: .zero, size: size))

        self.outlineView.style = .inset
        self.outlineView.rowHeight = Self.rowHeight
        self.outlineView.usesAlternatingRowBackgroundColors = true
        self.outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        self.outlineView.indentationPerLevel = Self.indentation
        self.outlineView.dataSource = self
        self.outlineView.delegate = self

        for column in DeviceColumn.allCases {
            let tableColumn = NSTableColumn(identifier: column.identifier)
            tableColumn.title = column.layout.title
            tableColumn.width = column.layout.width
            tableColumn.minWidth = column.layout.minWidth
            self.outlineView.addTableColumn(tableColumn)
        }
        self.outlineView.outlineTableColumn = self.outlineView.tableColumn(withIdentifier: DeviceColumn.device.identifier)

        self.rescanButton.target = self
        self.rescanButton.action = #selector(self.rescanDevices)
        self.rescanButton.bezelStyle = .rounded
        self.rescanButton.frame = NSRect(origin: NSPoint(x: Self.padding, y: Self.padding), size: Self.buttonSize)
        self.rescanButton.autoresizingMask = [.maxYMargin]
        self.view.addSubview(self.rescanButton)

        let labelX = Self.padding + Self.buttonSize.width + Self.gap
        self.notificationsDeniedLabel.frame = NSRect(
            x: labelX,
            y: Self.padding,
            width: size.width - labelX - Self.padding,
            height: Self.buttonSize.height
        )
        self.notificationsDeniedLabel.font = .systemFont(ofSize: Self.cellFontSize)
        self.notificationsDeniedLabel.textColor = .secondaryLabelColor
        self.notificationsDeniedLabel.lineBreakMode = .byTruncatingTail
        self.notificationsDeniedLabel.autoresizingMask = [.maxYMargin, .width]
        self.notificationsDeniedLabel.isHidden = true
        self.view.addSubview(self.notificationsDeniedLabel)

        let scrollY = Self.padding + Self.buttonSize.height + Self.gap
        let scrollView = NSScrollView(
            frame: NSRect(x: Self.padding, y: scrollY, width: size.width - 2 * Self.padding, height: size.height - Self.padding - scrollY)
        )
        scrollView.documentView = self.outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]
        self.view.addSubview(scrollView)
    }

    override func viewDidLoad() -> Void {
        super.viewDidLoad()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.handleContentDidChange), name: .sensorDevicesDidChange, object: self.sensorManager)
        center.addObserver(self, selector: #selector(self.handleContentDidChange), name: .aranetScanStateDidChange, object: self.sensorManager)
        center.addObserver(self, selector: #selector(self.handleContentDidChange), name: .preferencesDidChange, object: self.preferences)
    }

    override func viewWillAppear() -> Void {
        super.viewWillAppear()
        self.reloadOutlineData()
        self.refreshNotificationAuthorization()
    }

    // MARK: - Private

    private var isScanning: Bool {
        return self.sensorManager?.isScanning == true
    }

    @objc private func handleContentDidChange() -> Void {
        self.reloadOutlineData()
    }

    @objc private func rescanDevices() -> Void {
        self.sensorManager?.rescan()
    }

    private func reloadOutlineData() -> Void {
        self.rescanButton.isEnabled = self.isScanning == false

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
        guard let sensorManager = self.sensorManager else {
            self.deviceItems.removeAll()
            self.metricItemsByDeviceId.removeAll()
            return
        }
        guard sensorManager.isScanning == false else {
            self.deviceItems.removeAll()
            self.metricItemsByDeviceId.removeAll()
            return
        }

        let devices = sensorManager.sortedDevices
        self.deviceItems = devices.map { DeviceOutlineItem(deviceId: $0.device.id) }
        self.metricItemsByDeviceId = Dictionary(
            uniqueKeysWithValues: devices.map { monitored in
                let metrics = StatusBarDisplayMetric.availableMetrics(for: monitored.reading).map {
                    MetricOutlineItem(deviceId: monitored.device.id, metric: $0)
                }
                return (monitored.device.id, metrics)
            }
        )
    }

    private func currentExpandedDeviceIds() -> Set<UUID> {
        return Set(self.deviceItems.compactMap { self.outlineView.isItemExpanded($0) == true ? $0.deviceId : nil })
    }

    private func monitoredDevice(withId deviceId: UUID) -> MonitoredDevice? {
        return self.sensorManager?.devices[deviceId]
    }

    /// The connection state when it needs attention, otherwise the age of the latest reading.
    private func statusText(for monitored: MonitoredDevice) -> String {
        if let columnText = monitored.connectionState.columnText {
            return columnText
        }
        guard monitored.reading != nil else { return "Searching\u{2026}" }
        guard let lastUpdated = monitored.lastUpdated else { return "Searching\u{2026}" }
        return Self.relativeFormatter.localizedString(for: lastUpdated, relativeTo: self.now())
    }

    /// Shows the System Settings hint when the user denied notifications but enabled them for a device.
    private func refreshNotificationAuthorization() -> Void {
        Task { [weak self] in
            let denied = await NotificationManager.isAuthorizationDenied()
            self?.showNotificationAuthorization(denied: denied)
        }
    }

    private func showNotificationAuthorization(denied: Bool) -> Void {
        let anyEnabled = self.deviceItems.contains { self.preferences.notificationsEnabled(for: $0.deviceId) == true }
        self.notificationsDeniedLabel.isHidden = denied == false || anyEnabled == false
    }
}

extension DevicesViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if self.isScanning == true {
            return item == nil ? 1 : 0
        }
        if let deviceItem = item as? DeviceOutlineItem {
            return self.metricItemsByDeviceId[deviceItem.deviceId]?.count ?? 0
        }
        return item == nil ? self.deviceItems.count : 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if self.isScanning == true {
            return self.scanningItem
        }
        if let deviceItem = item as? DeviceOutlineItem {
            let metricItems = self.metricItemsByDeviceId[deviceItem.deviceId] ?? []
            guard metricItems.indices.contains(index) == true else { return self.scanningItem }
            return metricItems[index]
        }
        guard self.deviceItems.indices.contains(index) == true else { return self.scanningItem }
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
        guard let identifier = tableColumn?.identifier else { return nil }
        guard let column = DeviceColumn(rawValue: identifier.rawValue) else { return nil }

        if item is ScanningOutlineItem {
            guard column == .device else { return nil }
            let cell = self.textCell(identifier: Self.scanningCellIdentifier, in: outlineView)
            cell.stringValue = "Scanning for devices\u{2026}"
            cell.textColor = .secondaryLabelColor
            return cell
        }
        if let metricItem = item as? MetricOutlineItem {
            return self.view(for: metricItem, column: column, in: outlineView)
        }
        guard let deviceItem = item as? DeviceOutlineItem else { return nil }
        guard let monitored = self.monitoredDevice(withId: deviceItem.deviceId) else { return nil }
        return self.view(for: monitored, column: column, in: outlineView)
    }

    private func view(for monitored: MonitoredDevice, column: DeviceColumn, in outlineView: NSOutlineView) -> NSView? {
        let cellIdentifier = column.cellIdentifier(isMetricRow: false)

        switch column {
            case .notifications:
                let button = self.checkboxCell(identifier: cellIdentifier, action: #selector(self.notificationToggleChanged(_:)), in: outlineView)
                button.state = self.preferences.notificationsEnabled(for: monitored.device.id) == true ? .on : .off
                return button
            case .menuBar:
                return nil
            case .name:
                return self.nameCell(for: monitored, identifier: cellIdentifier, in: outlineView)
            case .device:
                let cell = self.textCell(identifier: cellIdentifier, in: outlineView)
                cell.stringValue = monitored.reportedName
                cell.textColor = .labelColor
                return cell
            case .uuid:
                let cell = self.textCell(identifier: cellIdentifier, in: outlineView)
                cell.stringValue = monitored.device.id.uuidString
                cell.textColor = .secondaryLabelColor
                return cell
            case .type:
                let cell = self.textCell(identifier: cellIdentifier, in: outlineView)
                cell.stringValue = monitored.reading?.deviceType.name ?? "\u{2014}"
                cell.textColor = monitored.reading != nil ? .labelColor : .secondaryLabelColor
                return cell
            case .status:
                let cell = self.textCell(identifier: cellIdentifier, in: outlineView)
                cell.stringValue = self.statusText(for: monitored)
                cell.textColor = monitored.reading != nil ? .labelColor : .secondaryLabelColor
                return cell
        }
    }

    private func view(for item: MetricOutlineItem, column: DeviceColumn, in outlineView: NSOutlineView) -> NSView? {
        let cellIdentifier = column.cellIdentifier(isMetricRow: true)

        switch column {
            case .device:
                let cell = self.textCell(identifier: cellIdentifier, in: outlineView)
                cell.stringValue = item.metric.label
                cell.textColor = .labelColor
                return cell
            case .status:
                let cell = self.textCell(identifier: cellIdentifier, in: outlineView)
                let reading = self.monitoredDevice(withId: item.deviceId)?.reading
                let value = reading.flatMap { item.metric.valueString(for: $0, unitSystem: self.preferences.displayUnitSystem) }
                cell.stringValue = value ?? "\u{2014}"
                cell.textColor = value != nil ? .labelColor : .secondaryLabelColor
                return cell
            case .menuBar:
                let button = self.checkboxCell(identifier: cellIdentifier, action: #selector(self.menuBarMetricChanged(_:)), in: outlineView)
                let selection = self.preferences.statusBarSelection
                button.state = selection?.contains(item.metric, of: item.deviceId) == true ? .on : .off
                button.isEnabled = StatusBarDisplaySelection.canSelect(item.metric, of: item.deviceId, in: selection)
                return button
            case .uuid:
                return nil
            case .name:
                return nil
            case .type:
                return nil
            case .notifications:
                return nil
        }
    }

    private func nameCell(for monitored: MonitoredDevice, identifier: NSUserInterfaceItemIdentifier, in outlineView: NSOutlineView) -> NSView {
        let field: DeviceNameTextField
        if let existing = outlineView.makeView(withIdentifier: identifier, owner: nil) as? DeviceNameTextField {
            field = existing
        }
        else {
            field = DeviceNameTextField()
            field.identifier = identifier
            field.isBordered = false
            field.drawsBackground = false
            field.lineBreakMode = .byTruncatingTail
            field.font = .systemFont(ofSize: Self.cellFontSize)
            field.delegate = self
        }
        field.deviceId = monitored.device.id
        field.stringValue = self.preferences.deviceName(for: monitored.device.id) ?? ""
        field.placeholderString = monitored.reportedName
        return field
    }

    private func textCell(identifier: NSUserInterfaceItemIdentifier, in outlineView: NSOutlineView) -> NSTextField {
        if let existing = outlineView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField {
            return existing
        }

        let cell = NSTextField(labelWithString: "")
        cell.identifier = identifier
        cell.lineBreakMode = .byTruncatingTail
        cell.font = .systemFont(ofSize: Self.cellFontSize)
        return cell
    }

    private func checkboxCell(identifier: NSUserInterfaceItemIdentifier, action: Selector, in outlineView: NSOutlineView) -> NSButton {
        if let existing = outlineView.makeView(withIdentifier: identifier, owner: nil) as? NSButton {
            return existing
        }

        let button = NSButton(checkboxWithTitle: "", target: self, action: action)
        button.identifier = identifier
        return button
    }

    @objc private func notificationToggleChanged(_ sender: NSButton) -> Void {
        let row = self.outlineView.row(for: sender)
        guard row >= 0 else { return }
        guard let item = self.outlineView.item(atRow: row) as? DeviceOutlineItem else { return }

        let enabled = sender.state == .on
        self.preferences.setNotificationsEnabled(enabled, for: item.deviceId)
        guard enabled == true else {
            self.refreshNotificationAuthorization()
            return
        }

        Task { [weak self] in
            await NotificationManager.requestAuthorization()
            self?.refreshNotificationAuthorization()
        }
    }

    @objc private func menuBarMetricChanged(_ sender: NSButton) -> Void {
        let row = self.outlineView.row(for: sender)
        guard row >= 0 else { return }
        guard let item = self.outlineView.item(atRow: row) as? MetricOutlineItem else { return }
        self.preferences.toggleStatusBarMetric(item.metric, of: item.deviceId)
    }
}

extension DevicesViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) -> Void {
        guard let field = obj.object as? DeviceNameTextField else { return }
        guard let deviceId = field.deviceId else { return }
        self.preferences.setDeviceName(field.stringValue, for: deviceId)
    }
}
