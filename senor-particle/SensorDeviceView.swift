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

    override var isFlipped: Bool { true }

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
        setupFixedSubviews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Configuration

    func configure(device: AranetDevice, reading: AranetReading?, lastUpdated: Date? = nil, updateSequence: UInt = 0) {
        nameLabel.stringValue =
            DeviceNamePreferences.name(for: device.id)
            ?? reading?.name
            ?? device.name

        let batteryWidth: CGFloat = 56
        batteryView.frame = NSRect(
            x: frame.width - rightPadding - batteryWidth, y: topPadding, width: batteryWidth, height: nameRowHeight)

        nameLabel.frame = NSRect(
            x: contentLeft, y: topPadding, width: frame.width - contentLeft - rightPadding - batteryWidth - 4,
            height: nameRowHeight)

        let status = SensorSymbol.effectiveStatus(from: reading)

        if let reading {
            iconView.image = SensorSymbol.image(for: reading.deviceType, status: status, pointSize: iconSymbolPointSize)
            iconView.contentTintColor = .white
            iconBackgroundView.layer?.backgroundColor = backgroundForStatus(status).cgColor
            batteryView.configure(battery: Int(reading.battery))
        }
        else {
            iconView.image = SensorSymbol.scanningImage(pointSize: iconSymbolPointSize, weight: .semibold)
            iconView.contentTintColor = .white
            iconBackgroundView.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            batteryView.clear()
        }

        let rows = readingRows(from: reading)
        ensureMetricRows(count: rows.count)

        let valueX = contentLeft + labelWidth
        let valueWidth = frame.width - valueX - rightPadding
        var y = topPadding + nameRowHeight + nameBottomGap

        for (index, row) in rows.enumerated() {
            let metricRow = metricRows[index]
            metricRow.labelField.stringValue = row.label
            metricRow.valueField.stringValue = row.value
            metricRow.labelField.frame = NSRect(x: contentLeft, y: y, width: labelWidth, height: rowHeight)
            metricRow.valueField.frame = NSRect(x: valueX, y: y, width: valueWidth, height: rowHeight)
            metricRow.labelField.isHidden = false
            metricRow.valueField.isHidden = false
            y += rowHeight + rowSpacing
        }

        for index in rows.count ..< metricRows.count {
            metricRows[index].labelField.isHidden = true
            metricRows[index].valueField.isHidden = true
        }

        if let lastUpdated, let reading {
            y += 2
            timestampField.stringValue = formatTimestamp(sensorMeasurementDate(receivedAt: lastUpdated, reading: reading))
            timestampField.frame = NSRect(x: contentLeft, y: y, width: frame.width - contentLeft - rightPadding, height: 14)
            timestampField.isHidden = false
            y += 14

            y += progressTopGap
            let progressWidth = frame.width - contentLeft - rightPadding
            updateCycleProgress.frame = NSRect(x: contentLeft, y: y, width: progressWidth, height: progressHeight)
            updateCycleProgress.configure(
                lastUpdated: lastUpdated, reading: reading, updateSequence: updateSequence)
            y += progressHeight
        }
        else {
            timestampField.isHidden = true
            updateCycleProgress.clear()
        }

        let totalHeight = y - rowSpacing + bottomPadding
        setFrameSize(NSSize(width: frame.width, height: totalHeight))

        let badgeY = topPadding + (nameRowHeight - badgeSize) / 2
        layoutIconBadge(at: badgeY, deviceType: reading?.deviceType)

        invalidateDisplay()
    }

    private func layoutIconBadge(at badgeY: CGFloat, deviceType: AranetDeviceType?) {
        let badgeFrame = NSRect(x: leftPadding, y: badgeY, width: badgeSize, height: badgeSize)
        iconBackgroundView.frame = badgeFrame
        iconBackgroundView.layer?.cornerRadius = badgeSize / 2

        let iconInset = (badgeSize - iconViewSize) / 2
        let offset = deviceType.map { SensorSymbol.alignmentOffset(for: $0) } ?? .zero
        iconView.frame = NSRect(
            x: badgeFrame.minX + iconInset + offset.width,
            y: badgeFrame.minY + iconInset + offset.height,
            width: iconViewSize,
            height: iconViewSize
        )
    }

    // MARK: - Setup

    private func setupFixedSubviews() {
        iconBackgroundView.wantsLayer = true
        iconBackgroundView.layer?.masksToBounds = true
        addSubview(iconBackgroundView)

        iconView.imageScaling = .scaleProportionallyDown
        iconView.imageAlignment = .alignCenter
        addSubview(iconView)

        configureLabel(nameLabel, size: 13, weight: .semibold)
        addSubview(nameLabel)

        addSubview(batteryView)

        configureLabel(timestampField, size: 10, weight: .regular)
        timestampField.textColor = .secondaryLabelColor
        timestampField.isHidden = true
        addSubview(timestampField)

        addSubview(updateCycleProgress)
    }

    private func configureLabel(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight) {
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.font = .systemFont(ofSize: size, weight: weight)
        label.lineBreakMode = .byTruncatingTail
    }

    private func makeLabel(size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField()
        configureLabel(label, size: size, weight: weight)
        return label
    }

    private func ensureMetricRows(count: Int) {
        let valueX = contentLeft + labelWidth
        let valueWidth = frame.width - valueX - rightPadding

        while metricRows.count < count {
            let labelField = makeLabel(size: 12, weight: .regular)
            labelField.textColor = .secondaryLabelColor

            let valueField = makeLabel(size: 12, weight: .medium)
            valueField.textColor = .labelColor
            valueField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)

            addSubview(labelField)
            addSubview(valueField)
            metricRows.append(MetricRow(labelField: labelField, valueField: valueField))
        }

        for metricRow in metricRows {
            metricRow.valueField.frame.size.width = valueWidth
        }
    }

    private func invalidateDisplay() {
        needsDisplay = true
        displayIfNeeded()

        for metricRow in metricRows {
            metricRow.labelField.needsDisplay = true
            metricRow.valueField.needsDisplay = true
        }
        timestampField.needsDisplay = true
        nameLabel.needsDisplay = true
        batteryView.needsDisplay = true
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
