import AranetKit
import Cocoa

class SensorDeviceView: NSView {
    private struct MetricRow {
        let labelField: NSTextField
        let valueField: NSTextField
    }

    private let iconBackgroundView = NSView()
    private let iconView = NSImageView()
    private let nameLabel = NSTextField()
    private let batteryView = BatteryView()
    private let timestampField = NSTextField()
    private let updateCycleProgress = UpdateCycleProgressView()
    private var metricRows: [MetricRow] = []

    override var isFlipped: Bool { return true }

    private let badgeSize: CGFloat = 24
    private let iconViewSize: CGFloat = 16
    private let iconSymbolPointSize: CGFloat = 12
    private let leftPadding: CGFloat = 12
    private let contentLeft: CGFloat = 42
    private let rightPadding: CGFloat = 14
    private let topPadding: CGFloat = 8
    private let bottomPadding: CGFloat = 8
    private let nameRowHeight: CGFloat = 18
    private let nameBottomGap: CGFloat = 2
    private let rowHeight: CGFloat = 16
    private let rowSpacing: CGFloat = 1
    private let labelWidth: CGFloat = 90
    private let progressHeight: CGFloat = 2
    private let progressTopGap: CGFloat = 6

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupFixedSubviews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Configuration

    func configure(device: AranetDevice, reading: AranetReading?, lastUpdated: Date? = nil, updateSequence: UInt = 0) -> Void {
        self.nameLabel.stringValue =
            DeviceNamePreferences.name(for: device.id)
            ?? reading?.name
            ?? device.name

        let batteryWidth: CGFloat = 56
        self.batteryView.frame = NSRect(
            x: self.frame.width - self.rightPadding - batteryWidth, y: self.topPadding, width: batteryWidth, height: self.nameRowHeight)

        self.nameLabel.frame = NSRect(
            x: self.contentLeft, y: self.topPadding, width: self.frame.width - self.contentLeft - self.rightPadding - batteryWidth - 4,
            height: self.nameRowHeight)

        let status = SensorSymbol.effectiveStatus(from: reading)

        if let reading {
            self.iconView.image = SensorSymbol.image(for: reading.deviceType, status: status, pointSize: self.iconSymbolPointSize)
            self.iconView.contentTintColor = .white
            self.iconBackgroundView.layer?.backgroundColor = self.backgroundForStatus(status).cgColor
            self.batteryView.configure(battery: Int(reading.battery))
        }
        else {
            self.iconView.image = SensorSymbol.scanningImage(pointSize: self.iconSymbolPointSize, weight: .semibold)
            self.iconView.contentTintColor = .white
            self.iconBackgroundView.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            self.batteryView.clear()
        }

        let rows = self.readingRows(from: reading)
        self.ensureMetricRows(count: rows.count)

        let valueX = self.contentLeft + self.labelWidth
        let valueWidth = self.frame.width - valueX - self.rightPadding
        var y = self.topPadding + self.nameRowHeight + self.nameBottomGap

        for (index, row) in rows.enumerated() {
            let metricRow = self.metricRows[index]
            metricRow.labelField.stringValue = row.label
            metricRow.valueField.stringValue = row.value
            metricRow.labelField.frame = NSRect(x: self.contentLeft, y: y, width: self.labelWidth, height: self.rowHeight)
            metricRow.valueField.frame = NSRect(x: valueX, y: y, width: valueWidth, height: self.rowHeight)
            metricRow.labelField.isHidden = false
            metricRow.valueField.isHidden = false
            y += self.rowHeight + self.rowSpacing
        }

        for index in rows.count ..< self.metricRows.count {
            self.metricRows[index].labelField.isHidden = true
            self.metricRows[index].valueField.isHidden = true
        }

        if let lastUpdated, let reading {
            y += 2
            self.timestampField.stringValue = self.formatTimestamp(self.sensorMeasurementDate(receivedAt: lastUpdated, reading: reading))
            self.timestampField.frame = NSRect(x: self.contentLeft, y: y, width: self.frame.width - self.contentLeft - self.rightPadding, height: 14)
            self.timestampField.isHidden = false
            y += 14

            y += self.progressTopGap
            let progressWidth = self.frame.width - self.contentLeft - self.rightPadding
            self.updateCycleProgress.frame = NSRect(x: self.contentLeft, y: y, width: progressWidth, height: self.progressHeight)
            self.updateCycleProgress.configure(
                lastUpdated: lastUpdated, reading: reading, updateSequence: updateSequence)
            y += self.progressHeight
        }
        else {
            self.timestampField.isHidden = true
            self.updateCycleProgress.clear()
        }

        let totalHeight = y - self.rowSpacing + self.bottomPadding
        self.setFrameSize(NSSize(width: self.frame.width, height: totalHeight))

        let badgeY = self.topPadding + (self.nameRowHeight - self.badgeSize) / 2
        self.layoutIconBadge(at: badgeY, deviceType: reading?.deviceType)

        self.invalidateDisplay()
    }

    private func layoutIconBadge(at badgeY: CGFloat, deviceType: AranetDeviceType?) -> Void {
        let badgeFrame = NSRect(x: self.leftPadding, y: badgeY, width: self.badgeSize, height: self.badgeSize)
        self.iconBackgroundView.frame = badgeFrame
        self.iconBackgroundView.layer?.cornerRadius = self.badgeSize / 2

        let iconInset = (self.badgeSize - self.iconViewSize) / 2
        let offset = deviceType.map { SensorSymbol.alignmentOffset(for: $0) } ?? .zero
        self.iconView.frame = NSRect(
            x: badgeFrame.minX + iconInset + offset.width,
            y: badgeFrame.minY + iconInset + offset.height,
            width: self.iconViewSize,
            height: self.iconViewSize
        )
    }

    // MARK: - Setup

    private func setupFixedSubviews() -> Void {
        self.iconBackgroundView.wantsLayer = true
        self.iconBackgroundView.layer?.masksToBounds = true
        self.addSubview(self.iconBackgroundView)

        self.iconView.imageScaling = .scaleProportionallyDown
        self.iconView.imageAlignment = .alignCenter
        self.addSubview(self.iconView)

        self.configureLabel(self.nameLabel, size: 13, weight: .semibold)
        self.addSubview(self.nameLabel)

        self.addSubview(self.batteryView)

        self.configureLabel(self.timestampField, size: 10, weight: .regular)
        self.timestampField.textColor = .secondaryLabelColor
        self.timestampField.isHidden = true
        self.addSubview(self.timestampField)

        self.addSubview(self.updateCycleProgress)
    }

    private func configureLabel(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight) -> Void {
        label.applyPlainLabelStyle()
        label.font = .systemFont(ofSize: size, weight: weight)
        label.lineBreakMode = .byTruncatingTail
    }

    private func makeLabel(size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField()
        configureLabel(label, size: size, weight: weight)
        return label
    }

    private func ensureMetricRows(count: Int) -> Void {
        let valueX = self.contentLeft + self.labelWidth
        let valueWidth = self.frame.width - valueX - self.rightPadding

        while self.metricRows.count < count {
            let labelField = self.makeLabel(size: 12, weight: .regular)
            labelField.textColor = .secondaryLabelColor

            let valueField = self.makeLabel(size: 12, weight: .medium)
            valueField.textColor = .labelColor
            valueField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)

            self.addSubview(labelField)
            self.addSubview(valueField)
            self.metricRows.append(MetricRow(labelField: labelField, valueField: valueField))
        }

        for metricRow in self.metricRows {
            metricRow.valueField.frame.size.width = valueWidth
        }
    }

    private func invalidateDisplay() -> Void {
        self.needsDisplay = true
        self.displayIfNeeded()

        for metricRow in self.metricRows {
            metricRow.labelField.needsDisplay = true
            metricRow.valueField.needsDisplay = true
        }
        self.timestampField.needsDisplay = true
        self.nameLabel.needsDisplay = true
        self.batteryView.needsDisplay = true
    }

    // MARK: - Reading Rows

    private struct ReadingRow {
        let label: String
        let value: String
    }

    private func readingRows(from reading: AranetReading?) -> [ReadingRow] {
        guard let reading else { return [] }

        return StatusBarDisplayMetric.availableMetrics(for: reading).compactMap { metric in
            guard let value = metric.valueString(for: reading) else { return nil }
            return ReadingRow(label: metric.label, value: value)
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private func formatTimestamp(_ date: Date) -> String { return Self.timestampFormatter.string(from: date) }

    /// When the sensor recorded the reading, derived from app receive time minus device-reported age.
    private func sensorMeasurementDate(receivedAt: Date, reading: AranetReading) -> Date {
        receivedAt.addingTimeInterval(-TimeInterval(reading.ago ?? 0))
    }

    // MARK: - Appearance

    private func backgroundForStatus(_ status: AranetStatusColor?) -> NSColor {
        switch status {
            case .green: return NSColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1.0)
            case .yellow: return NSColor(red: 0.85, green: 0.55, blue: 0.10, alpha: 1.0)
            case .red: return NSColor(red: 0.70, green: 0.15, blue: 0.15, alpha: 1.0)
            default: return .tertiaryLabelColor
        }
    }
}
