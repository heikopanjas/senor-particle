import Cocoa

final class StatusItemPlaceholderView: NSView {
    private static let width: CGFloat = 34
    private static let symbolPointSize: CGFloat = 18
    private static let pulseLineWidth: CGFloat = 2
    private static let animationInterval: TimeInterval = 1.0 / 30.0
    private static let cycleDuration: TimeInterval = 1.4

    private var timer: Timer?
    private var animationStart = Date()
    private let symbolImage: NSImage?
    private let imageView = NSImageView()

    override var isFlipped: Bool { return true }

    override init(frame frameRect: NSRect) {
        self.symbolImage = SensorSymbol.scanningImage(pointSize: Self.symbolPointSize, weight: .semibold)
        super.init(frame: frameRect)
        self.setupSubviews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    isolated deinit {
        self.timer?.invalidate()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    func startAnimating() -> Void {
        self.isHidden = false
        self.animationStart = Date()
        self.needsDisplay = true

        guard self.timer == nil else { return }

        let newTimer = Timer(timeInterval: Self.animationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.needsDisplay = true
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }

    func stopAnimating() -> Void {
        self.timer?.invalidate()
        self.timer = nil
        self.isHidden = true
    }

    override func draw(_ dirtyRect: NSRect) -> Void {
        super.draw(dirtyRect)

        let center = NSPoint(x: self.bounds.midX, y: self.bounds.midY)
        let elapsed = Date().timeIntervalSince(self.animationStart)
        let progress = elapsed.truncatingRemainder(dividingBy: Self.cycleDuration) / Self.cycleDuration

        self.drawPulse(center: center, progress: progress)
    }

    @MainActor static func requiredWidth() -> CGFloat {
        return Self.width
    }

    override func setFrameSize(_ newSize: NSSize) -> Void {
        super.setFrameSize(newSize)
        self.layoutSymbol()
    }

    private func setupSubviews() -> Void {
        self.imageView.image = self.symbolImage
        self.imageView.imageScaling = .scaleProportionallyUpOrDown
        self.imageView.contentTintColor = .labelColor
        self.addSubview(self.imageView)
    }

    private func drawPulse(center: NSPoint, progress: Double) -> Void {
        let phases = [progress, (progress + 0.5).truncatingRemainder(dividingBy: 1.0)]

        for phase in phases {
            let easedPhase = CGFloat(phase)
            let radius = 9 + easedPhase * 5
            let alpha = max(0, 0.55 * (1 - easedPhase))
            let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let path = NSBezierPath(ovalIn: rect)

            NSColor.controlAccentColor.withAlphaComponent(alpha).setStroke()
            path.lineWidth = Self.pulseLineWidth
            path.stroke()
        }
    }

    private func layoutSymbol() -> Void {
        let size = NSSize(width: Self.symbolPointSize, height: Self.symbolPointSize)
        self.imageView.frame = NSRect(x: (self.bounds.width - size.width) / 2, y: (self.bounds.height - size.height) / 2, width: size.width, height: size.height)
    }
}
