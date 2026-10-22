import AranetKit
import Cocoa

/// One device row in the status menu: status badge, name, battery, measurements, connection state, and update cycle.
final class SensorDeviceView: NSView {
    private struct MetricRow {
        let labelField: NSTextField
        let valueField: NSTextField
    }

    private struct ReadingRow {
        let label: String
        let value: String
    }

    private static let badgeSize: CGFloat = 24
    private static let iconViewSize: CGFloat = 16
    private static let iconSymbolPointSize: CGFloat = 12
    private static let leftPadding: CGFloat = 12
    private static let contentLeft: CGFloat = 42
    private static let rightPadding: CGFloat = 14
    private static let topPadding: CGFloat = 8
    private static let bottomPadding: CGFloat = 8
    private static let nameRowHeight: CGFloat = 18
    private static let nameBottomGap: CGFloat = 2
    private static let nameBatteryGap: CGFloat = 4
    private static let batteryWidth: CGFloat = 56
    private static let rowHeight: CGFloat = 16
    private static let rowSpacing: CGFloat = 1
    private static let labelWidth: CGFloat = 90
    private static let detailTopGap: CGFloat = 2
    private static let detailHeight: CGFloat = 14
    private static let progressHeight: CGFloat = 2
    private static let progressTopGap: CGFloat = 6
    private static let nameFontSize: CGFloat = 13
    private static let metricFontSize: CGFloat = 12
    private static let detailFontSize: CGFloat = 10

    private static let greenBadgeColor = NSColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1.0)
    private static let yellowBadgeColor = NSColor(red: 0.85, green: 0.55, blue: 0.10, alpha: 1.0)
    private static let redBadgeColor = NSColor(red: 0.70, green: 0.15, blue: 0.15, alpha: 1.0)

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private let iconBackgroundView = NSView()
    private let iconView = NSImageView()
    private let nameLabel = NSTextField()
    private let batteryView = BatteryView()
    private let connectionField = NSTextField()
    private let timestampField = NSTextField()
    private let updateCycleProgress = UpdateCycleProgressView()
    private var metricRows: [MetricRow] = []

    override var isFlipped: Bool { return true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupFixedSubviews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Configuration

    /// Shows `monitored` under `displayName`, formatting values in `unitSystem`.
    func configure(_ monitored: MonitoredDevice, displayName: String, unitSystem: DisplayUnitSystem, degradedCycles: Int) -> Void {
        let reading = monitored.reading
        self.nameLabel.stringValue = displayName

        self.batteryView.frame = NSRect(
            x: self.frame.width - Self.rightPadding - Self.batteryWidth,
            y: Self.topPadding,
            width: Self.batteryWidth,
            height: Self.nameRowHeight
        )
        self.nameLabel.frame = NSRect(
            x: Self.contentLeft,
            y: Self.topPadding,
            width: self.frame.width - Self.contentLeft - Self.rightPadding - Self.batteryWidth - Self.nameBatteryGap,
            height: Self.nameRowHeight
        )

        self.configureBadge(for: reading)

        let rows = self.readingRows(from: reading, unitSystem: unitSystem)
        self.ensureMetricRows(count: rows.count)

        let valueX = Self.contentLeft + Self.labelWidth
        let valueWidth = self.frame.width - valueX - Self.rightPadding
        let detailWidth = self.frame.width - Self.contentLeft - Self.rightPadding
        var y = Self.topPadding + Self.nameRowHeight + Self.nameBottomGap

        for (index, row) in rows.enumerated() {
            let metricRow = self.metricRows[index]
            metricRow.labelField.stringValue = row.label
            metricRow.valueField.stringValue = row.value
            metricRow.labelField.frame = NSRect(x: Self.contentLeft, y: y, width: Self.labelWidth, height: Self.rowHeight)
            metricRow.valueField.frame = NSRect(x: valueX, y: y, width: valueWidth, height: Self.rowHeight)
            metricRow.labelField.isHidden = false
            metricRow.valueField.isHidden = false
            y += Self.rowHeight + Self.rowSpacing
        }

        for index in rows.count ..< self.metricRows.count {
            self.metricRows[index].labelField.isHidden = true
            self.metricRows[index].valueField.isHidden = true
        }

        if let connectionText = monitored.connectionState.menuText {
            y += Self.detailTopGap
            self.connectionField.stringValue = connectionText
            self.connectionField.frame = NSRect(x: Self.contentLeft, y: y, width: detailWidth, height: Self.detailHeight)
            self.connectionField.isHidden = false
            y += Self.detailHeight
        }
        else {
            self.connectionField.isHidden = true
        }

        if let lastUpdated = monitored.lastUpdated, let reading {
            y += Self.detailTopGap
            self.timestampField.stringValue = Self.timestampFormatter.string(from: Self.measurementDate(receivedAt: lastUpdated, reading: reading))
            self.timestampField.frame = NSRect(x: Self.contentLeft, y: y, width: detailWidth, height: Self.detailHeight)
            self.timestampField.isHidden = false
            y += Self.detailHeight

            y += Self.progressTopGap
            self.updateCycleProgress.frame = NSRect(x: Self.contentLeft, y: y, width: detailWidth, height: Self.progressHeight)
            self.updateCycleProgress.configure(
                lastUpdated: lastUpdated,
                reading: reading,
                updateSequence: monitored.updateSequence,
                degradedCycles: degradedCycles
            )
            y += Self.progressHeight
        }
        else {
            self.timestampField.isHidden = true
            self.updateCycleProgress.clear()
        }

        self.setFrameSize(NSSize(width: self.frame.width, height: y - Self.rowSpacing + Self.bottomPadding))
        self.layoutIconBadge(at: Self.topPadding + (Self.nameRowHeight - Self.badgeSize) / 2, deviceType: reading?.deviceType)
        self.invalidateDisplay()
    }

    // MARK: - Setup

    private func setupFixedSubviews() -> Void {
        self.iconBackgroundView.wantsLayer = true
        self.iconBackgroundView.layer?.masksToBounds = true
        self.addSubview(self.iconBackgroundView)

        self.iconView.imageScaling = .scaleProportionallyDown
        self.iconView.imageAlignment = .alignCenter
        self.addSubview(self.iconView)

        self.configureLabel(self.nameLabel, size: Self.nameFontSize, weight: .semibold)
        self.addSubview(self.nameLabel)

        self.addSubview(self.batteryView)

        for field in [self.connectionField, self.timestampField] {
            self.configureLabel(field, size: Self.detailFontSize, weight: .regular)
            field.textColor = .secondaryLabelColor
            field.isHidden = true
            self.addSubview(field)
        }

        self.addSubview(self.updateCycleProgress)
    }

    private func configureLabel(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight) -> Void {
        label.applyPlainLabelStyle()
        label.font = .systemFont(ofSize: size, weight: weight)
        label.lineBreakMode = .byTruncatingTail
    }

    private func makeLabel(size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField()
        self.configureLabel(label, size: size, weight: weight)
        return label
    }

    private func ensureMetricRows(count: Int) -> Void {
        let valueX = Self.contentLeft + Self.labelWidth
        let valueWidth = self.frame.width - valueX - Self.rightPadding

        while self.metricRows.count < count {
            let labelField = self.makeLabel(size: Self.metricFontSize, weight: .regular)
            labelField.textColor = .secondaryLabelColor

            let valueField = self.makeLabel(size: Self.metricFontSize, weight: .medium)
            valueField.textColor = .labelColor
            valueField.font = .monospacedDigitSystemFont(ofSize: Self.metricFontSize, weight: .medium)

            self.addSubview(labelField)
            self.addSubview(valueField)
            self.metricRows.append(MetricRow(labelField: labelField, valueField: valueField))
        }

        for metricRow in self.metricRows {
            metricRow.valueField.frame.size.width = valueWidth
        }
    }

    // MARK: - Layout

    private func configureBadge(for reading: AranetReading?) -> Void {
        self.iconView.contentTintColor = .white
        guard let reading else {
            self.iconView.image = SensorSymbol.scanningImage(pointSize: Self.iconSymbolPointSize, weight: .semibold)
            self.iconBackgroundView.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            self.batteryView.clear()
            return
        }

        let status = SensorSymbol.effectiveStatus(from: reading)
        self.iconView.image = SensorSymbol.image(for: reading.deviceType, status: status, pointSize: Self.iconSymbolPointSize)
        self.iconBackgroundView.layer?.backgroundColor = Self.badgeColor(for: status).cgColor
        self.batteryView.configure(battery: Int(reading.battery))
    }

    private func layoutIconBadge(at badgeY: CGFloat, deviceType: AranetDeviceType?) -> Void {
        let badgeFrame = NSRect(x: Self.leftPadding, y: badgeY, width: Self.badgeSize, height: Self.badgeSize)
        self.iconBackgroundView.frame = badgeFrame
        self.iconBackgroundView.layer?.cornerRadius = Self.badgeSize / 2

        let iconInset = (Self.badgeSize - Self.iconViewSize) / 2
        let offset = deviceType.map { SensorSymbol.alignmentOffset(for: $0) } ?? .zero
        self.iconView.frame = NSRect(
            x: badgeFrame.minX + iconInset + offset.width,
            y: badgeFrame.minY + iconInset + offset.height,
            width: Self.iconViewSize,
            height: Self.iconViewSize
        )
    }

    private func invalidateDisplay() -> Void {
        self.needsDisplay = true
        self.displayIfNeeded()

        for metricRow in self.metricRows {
            metricRow.labelField.needsDisplay = true
            metricRow.valueField.needsDisplay = true
        }
        self.connectionField.needsDisplay = true
        self.timestampField.needsDisplay = true
        self.nameLabel.needsDisplay = true
        self.batteryView.needsDisplay = true
    }

    // MARK: - Content

    private func readingRows(from reading: AranetReading?, unitSystem: DisplayUnitSystem) -> [ReadingRow] {
        guard let reading else { return [] }

        return StatusBarDisplayMetric.availableMetrics(for: reading).compactMap { metric in
            guard let value = metric.valueString(for: reading, unitSystem: unitSystem) else { return nil }
            return ReadingRow(label: metric.label, value: value)
        }
    }

    /// When the sensor recorded the reading: the app's receive time minus the age the device reported.
    private static func measurementDate(receivedAt: Date, reading: AranetReading) -> Date {
        return receivedAt.addingTimeInterval(-TimeInterval(reading.ago ?? 0))
    }

    private static func badgeColor(for status: AranetStatusColor?) -> NSColor {
        switch status {
            case .green:
                return Self.greenBadgeColor
            case .yellow:
                return Self.yellowBadgeColor
            case .red:
                return Self.redBadgeColor
            case .error:
                return .tertiaryLabelColor
            case nil:
                return .tertiaryLabelColor
        }
    }
}
