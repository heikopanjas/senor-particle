import AranetKit
import Cocoa

class UpdateCycleProgressView: NSView {
    private let trackView = NSView()
    private let fillView = NSView()

    private var cycleAnchor: Date?
    private var cycleStartAgo: TimeInterval = 0
    private var interval: TimeInterval = 300
    private var updateSequence: UInt = 0
    private var timer: Timer?

    private static let defaultInterval: TimeInterval = 300
    private static let cornerRadius: CGFloat = 1

    private static let lightGreen = NSColor(red: 0.20, green: 0.78, blue: 0.28, alpha: 1.0)
    private static let lightGreenFadedAlpha: CGFloat = 0.37
    private static let darkRed = NSColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1.0)

    override var isFlipped: Bool { return true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupSubviews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    isolated deinit {
        self.timer?.invalidate()
    }

    func configure(lastUpdated: Date, reading: AranetReading, updateSequence: UInt) -> Void {
        let newCycle = updateSequence != self.updateSequence
        self.updateSequence = updateSequence
        self.interval = Self.interval(for: reading)

        if newCycle == true {
            self.cycleAnchor = lastUpdated
            self.cycleStartAgo = TimeInterval(reading.ago ?? 0)
        }

        self.isHidden = false
        self.refresh()
        self.startTimer()
    }

    func clear() -> Void {
        self.cycleAnchor = nil
        self.cycleStartAgo = 0
        self.updateSequence = 0
        self.timer?.invalidate()
        self.timer = nil
        self.isHidden = true
        self.fillView.frame.size.width = 0
    }

    override func setFrameSize(_ newSize: NSSize) -> Void {
        super.setFrameSize(newSize)
        self.layoutBar(progress: self.currentProgress())
    }

    // MARK: - Private

    private func setupSubviews() -> Void {
        self.trackView.wantsLayer = true
        self.trackView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        self.trackView.layer?.cornerRadius = Self.cornerRadius
        self.trackView.layer?.masksToBounds = true
        self.addSubview(self.trackView)

        self.fillView.wantsLayer = true
        self.fillView.layer?.cornerRadius = Self.cornerRadius
        self.fillView.layer?.masksToBounds = true
        self.trackView.addSubview(self.fillView)

        self.isHidden = true
    }

    private func startTimer() -> Void {
        self.timer?.invalidate()
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }

    private func refresh() -> Void {
        guard let cycleAnchor = self.cycleAnchor else { return }

        let elapsed = self.cycleStartAgo + Date().timeIntervalSince(cycleAnchor)

        if elapsed >= self.interval * Double(self.degradedCycleThreshold) {
            self.fillView.layer?.backgroundColor = Self.darkRed.cgColor
            self.layoutBar(progress: 1)
        }
        else {
            let progress = self.cycleProgress(elapsed: elapsed)
            self.fillView.layer?.backgroundColor = Self.normalColor(progress: progress).cgColor
            self.layoutBar(progress: progress)
        }

        self.trackView.needsDisplay = true
        self.fillView.needsDisplay = true
    }

    /// Maps total elapsed time into a repeating 0...1 progress within each interval.
    private func cycleProgress(elapsed: TimeInterval) -> Double {
        let position = elapsed.truncatingRemainder(dividingBy: self.interval)
        return position / self.interval
    }

    private func currentProgress() -> Double {
        guard let cycleAnchor = self.cycleAnchor else { return 0 }

        let elapsed = self.cycleStartAgo + Date().timeIntervalSince(cycleAnchor)
        if elapsed >= self.interval * Double(self.degradedCycleThreshold) { return 1 }
        return self.cycleProgress(elapsed: elapsed)
    }

    private func layoutBar(progress: Double) -> Void {
        guard self.frame.width > 0, self.frame.height > 0 else { return }

        self.trackView.frame = self.bounds
        self.fillView.frame = NSRect(x: 0, y: 0, width: self.bounds.width * progress, height: self.bounds.height)
    }

    private static func interval(for reading: AranetReading) -> TimeInterval {
        TimeInterval(reading.interval.map { max($0, 1) } ?? UInt16(defaultInterval))
    }

    private var degradedCycleThreshold: Int {
        return DegradedSituationPreferences.cycles
    }

    private static func normalColor(progress: Double) -> NSColor {
        let t = min(max(progress, 0), 1)
        let alpha = Self.lightGreen.alphaComponent + (Self.lightGreenFadedAlpha - Self.lightGreen.alphaComponent) * t
        return NSColor(
            red: Self.lightGreen.redComponent,
            green: Self.lightGreen.greenComponent,
            blue: Self.lightGreen.blueComponent,
            alpha: alpha
        )
    }
}
