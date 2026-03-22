import AranetKit
import Cocoa

class SensorDeviceView: NSView {
    private let iconBackgroundView = NSView()
    private let iconView = NSImageView()
    private let nameLabel = NSTextField()
    private let batteryView = BatteryView()
    private var rowLabels: [NSTextField] = []
    private var rowValues: [NSTextField] = []

    override var isFlipped: Bool { true }

    private let badgeSize: CGFloat = 24
    private let iconSize: CGFloat = 14
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupFixedSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(device: AranetDevice, reading: AranetReading?, lastUpdated: Date? = nil) {
        nameLabel.stringValue = reading?.name ?? device.name

        let batteryWidth: CGFloat = 56
        batteryView.frame = NSRect(
            x: frame.width - rightPadding - batteryWidth,
            y: topPadding,
            width: batteryWidth,
            height: nameRowHeight
        )

        nameLabel.frame = NSRect(
            x: contentLeft,
            y: topPadding,
            width: frame.width - contentLeft - rightPadding - batteryWidth - 4,
            height: nameRowHeight
        )

        let status = effectiveStatus(from: reading)

        if let reading {
            iconView.image = iconForDeviceType(reading.deviceType)
            iconView.contentTintColor = .white
            iconBackgroundView.layer?.backgroundColor = backgroundForStatus(status).cgColor
            batteryView.configure(battery: Int(reading.battery))
        }
        else {
            iconView.image = NSImage(
                systemSymbolName: "dot.radiowaves.left.and.right",
                accessibilityDescription: "sensor"
            )
            iconView.contentTintColor = .white
            iconBackgroundView.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            batteryView.clear()
        }

        for label in rowLabels { label.removeFromSuperview() }
        for value in rowValues { value.removeFromSuperview() }
        rowLabels.removeAll()
        rowValues.removeAll()

        let rows = readingRows(from: reading)
        let valueX = contentLeft + labelWidth
        let valueWidth = frame.width - valueX - rightPadding

        var y = topPadding + nameRowHeight + nameBottomGap

        for row in rows {
            let labelField = makeLabel(size: 12, weight: .regular)
            labelField.stringValue = row.label
            labelField.textColor = .tertiaryLabelColor
            labelField.frame = NSRect(x: contentLeft, y: y, width: labelWidth, height: rowHeight)
            addSubview(labelField)
            rowLabels.append(labelField)

            let valueField = makeLabel(size: 12, weight: .medium)
            valueField.stringValue = row.value
            valueField.textColor = .labelColor
            valueField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            valueField.frame = NSRect(x: valueX, y: y, width: valueWidth, height: rowHeight)
            addSubview(valueField)
            rowValues.append(valueField)

            y += rowHeight + rowSpacing
        }

        if let lastUpdated, reading != nil {
            y += 2
            let ageField = makeLabel(size: 10, weight: .regular)
            ageField.textColor = .tertiaryLabelColor
            ageField.stringValue = formatTimestamp(lastUpdated)
            ageField.frame = NSRect(x: contentLeft, y: y, width: frame.width - contentLeft - rightPadding, height: 14)
            addSubview(ageField)
            rowLabels.append(ageField)
            y += 14
        }

        let totalHeight = y - rowSpacing + bottomPadding
        setFrameSize(NSSize(width: frame.width, height: totalHeight))

        let badgeY = topPadding + (nameRowHeight - badgeSize) / 2
        iconBackgroundView.frame = NSRect(x: leftPadding, y: badgeY, width: badgeSize, height: badgeSize)
        iconBackgroundView.layer?.cornerRadius = badgeSize / 2

        let iconInset = (badgeSize - iconSize) / 2
        iconView.frame = NSRect(
            x: leftPadding + iconInset,
            y: badgeY + iconInset,
            width: iconSize,
            height: iconSize
        )
    }

    // MARK: - Setup

    private func setupFixedSubviews() {
        iconBackgroundView.wantsLayer = true
        iconBackgroundView.layer?.masksToBounds = true
        addSubview(iconBackgroundView)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        configureLabel(nameLabel, size: 13, weight: .semibold)
        addSubview(nameLabel)

        addSubview(batteryView)
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

    // MARK: - Reading Rows

    private struct ReadingRow {
        let label: String
        let value: String
    }

    private func readingRows(from reading: AranetReading?) -> [ReadingRow] {
        guard let reading else {
            return [ReadingRow(label: "", value: "Connecting\u{2026}")]
        }

        var rows: [ReadingRow] = []

        if let co2 = reading.co2 {
            rows.append(ReadingRow(label: "CO\u{2082}", value: "\(co2) ppm"))
        }
        if let temp = reading.temperature {
            rows.append(ReadingRow(label: "Temperature", value: String(format: "%.1f \u{00B0}C", temp.value)))
        }
        if let humidity = reading.humidity {
            rows.append(ReadingRow(label: "Humidity", value: "\(humidity)%"))
        }
        if let pressure = reading.pressure {
            rows.append(ReadingRow(label: "Pressure", value: String(format: "%.1f hPa", pressure.value)))
        }
        if let rate = reading.radiationRate {
            let uSv = rate.converted(to: .microsieverts)
            rows.append(ReadingRow(label: "Dose rate", value: String(format: "%.3f \u{00B5}Sv/h", uSv.value)))
        }
        if let total = reading.radiationTotal {
            let uSv = total.converted(to: .microsieverts)
            rows.append(ReadingRow(label: "Total dose", value: String(format: "%.2f \u{00B5}Sv", uSv.value)))
        }

        return rows
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private func formatTimestamp(_ date: Date) -> String {
        return Self.timestampFormatter.string(from: date)
    }

    // MARK: - Status

    /// Returns a status color for the device. Aranet4, Aranet Radiation, and
    /// Aranet Radon provide native status via AranetKit; Aranet2 defaults to green.
    private func effectiveStatus(from reading: AranetReading?) -> AranetStatusColor? {
        guard let reading else { return nil }
        if let status = reading.status { return status }
        if reading.temperature != nil || reading.humidity != nil { return .green }
        return nil
    }

    // MARK: - Appearance

    private func iconForDeviceType(_ type: AranetDeviceType) -> NSImage? {
        let name: String
        switch type {
            case .aranet4: name = "wind"
            case .aranet2: name = "thermometer.medium"
            case .aranetRadiation: name = "atom"
            case .aranetRadon: name = "humidity.fill"
            case .unknown: name = "dot.radiowaves.left.and.right"
        }
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
        return NSImage(systemSymbolName: name, accessibilityDescription: type.name)?
            .withSymbolConfiguration(config)
    }

    private func backgroundForStatus(_ status: AranetStatusColor?) -> NSColor {
        switch status {
            case .green: return NSColor(red: 0.18, green: 0.55, blue: 0.22, alpha: 1.0)
            case .yellow: return NSColor(red: 0.85, green: 0.55, blue: 0.10, alpha: 1.0)
            case .red: return NSColor(red: 0.70, green: 0.15, blue: 0.15, alpha: 1.0)
            default: return .tertiaryLabelColor
        }
    }
}
