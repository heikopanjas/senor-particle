import Cocoa

class BatteryView: NSView {
    private let imageView = NSImageView()
    private let label = NSTextField()

    private let iconHeight: CGFloat = 12
    private let iconWidth: CGFloat = 22
    private let spacing: CGFloat = 2
    private let criticalBatteryThreshold = 7

    override var isFlipped: Bool { return true }

    override func setFrameSize(_ newSize: NSSize) -> Void {
        super.setFrameSize(newSize)
        self.layoutContent()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupSubviews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(battery: Int) -> Void {
        self.label.stringValue = "\(battery)%"
        self.label.sizeToFit()

        let symbolName = self.batterySymbolName(for: battery)
        let config = NSImage.SymbolConfiguration(pointSize: self.iconHeight, weight: .regular)
        self.imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Battery \(battery)%")?.withSymbolConfiguration(config)
        self.imageView.contentTintColor = battery < self.criticalBatteryThreshold ? .systemRed : .secondaryLabelColor

        self.layoutContent()
    }

    func clear() -> Void {
        self.label.stringValue = ""
        self.imageView.image = nil
    }

    // MARK: - Private

    private func setupSubviews() -> Void {
        self.imageView.imageScaling = .scaleProportionallyUpOrDown
        self.addSubview(self.imageView)

        self.label.applyPlainLabelStyle()
        self.label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        self.label.textColor = .secondaryLabelColor
        self.label.alignment = .right
        self.addSubview(self.label)
    }

    private func layoutContent() -> Void {
        guard self.frame.width > 0 else { return }
        let labelWidth = self.label.intrinsicContentSize.width
        let labelHeight = self.label.intrinsicContentSize.height
        let totalWidth = self.iconWidth + self.spacing + labelWidth
        let x = self.frame.width - totalWidth
        let iconY = (self.frame.height - self.iconHeight) / 2
        let labelY = (self.frame.height - labelHeight) / 2

        self.imageView.frame = NSRect(x: x, y: iconY, width: self.iconWidth, height: self.iconHeight)
        self.label.frame = NSRect(x: x + self.iconWidth + self.spacing, y: labelY, width: labelWidth, height: labelHeight)
    }

    private func batterySymbolName(for level: Int) -> String {
        if level < 13 { return "battery.0percent" }
        if level < 38 { return "battery.25percent" }
        if level < 63 { return "battery.50percent" }
        if level < 88 { return "battery.75percent" }
        return "battery.100percent"
    }
}
