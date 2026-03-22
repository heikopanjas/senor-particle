import Cocoa

class BatteryView: NSView {
    private let imageView = NSImageView()
    private let label = NSTextField()

    private let iconHeight: CGFloat = 12
    private let iconWidth: CGFloat = 22
    private let spacing: CGFloat = 2

    override var isFlipped: Bool { true }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutContent()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(battery: Int) {
        label.stringValue = "\(battery)%"
        label.sizeToFit()

        let symbolName = batterySymbolName(for: battery)
        let config = NSImage.SymbolConfiguration(pointSize: iconHeight, weight: .regular)
        imageView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Battery \(battery)%"
        )?.withSymbolConfiguration(config)
        imageView.contentTintColor = battery < 7 ? .systemRed : .secondaryLabelColor

        layoutContent()
    }

    func clear() {
        label.stringValue = ""
        imageView.image = nil
    }

    // MARK: - Private

    private func setupSubviews() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)

        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        addSubview(label)
    }

    private func layoutContent() {
        guard frame.width > 0 else { return }
        let labelWidth = label.intrinsicContentSize.width
        let labelHeight = label.intrinsicContentSize.height
        let totalWidth = iconWidth + spacing + labelWidth
        let x = frame.width - totalWidth
        let iconY = (frame.height - iconHeight) / 2
        let labelY = (frame.height - labelHeight) / 2

        imageView.frame = NSRect(x: x, y: iconY, width: iconWidth, height: iconHeight)
        label.frame = NSRect(x: x + iconWidth + spacing, y: labelY, width: labelWidth, height: labelHeight)
    }

    private func batterySymbolName(for level: Int) -> String {
        if level < 7 { return "battery.0percent" }
        if level < 13 { return "battery.0percent" }
        if level < 38 { return "battery.25percent" }
        if level < 63 { return "battery.50percent" }
        if level < 88 { return "battery.75percent" }
        return "battery.100percent"
    }
}
