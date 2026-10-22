import Cocoa

/// Battery icon and percentage, right-aligned in the device row of the status menu.
final class BatteryView: NSView {
    private static let iconHeight: CGFloat = 12
    private static let iconWidth: CGFloat = 22
    private static let spacing: CGFloat = 2
    private static let fontSize: CGFloat = 11

    private let imageView = NSImageView()
    private let label = NSTextField()

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

        let config = NSImage.SymbolConfiguration(pointSize: Self.iconHeight, weight: .regular)
        let image = NSImage(systemSymbolName: BatteryLevel.symbolName(for: battery), accessibilityDescription: "Battery \(battery)%")
        self.imageView.image = image?.withSymbolConfiguration(config)
        self.imageView.contentTintColor = BatteryLevel.isCritical(battery) == true ? .systemRed : .secondaryLabelColor

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
        self.label.font = .monospacedDigitSystemFont(ofSize: Self.fontSize, weight: .regular)
        self.label.textColor = .secondaryLabelColor
        self.label.alignment = .right
        self.addSubview(self.label)
    }

    private func layoutContent() -> Void {
        guard self.frame.width > 0 else { return }
        let labelWidth = self.label.intrinsicContentSize.width
        let labelHeight = self.label.intrinsicContentSize.height
        let totalWidth = Self.iconWidth + Self.spacing + labelWidth
        let x = self.frame.width - totalWidth
        let iconY = (self.frame.height - Self.iconHeight) / 2
        let labelY = (self.frame.height - labelHeight) / 2

        self.imageView.frame = NSRect(x: x, y: iconY, width: Self.iconWidth, height: Self.iconHeight)
        self.label.frame = NSRect(x: x + Self.iconWidth + Self.spacing, y: labelY, width: labelWidth, height: labelHeight)
    }
}
