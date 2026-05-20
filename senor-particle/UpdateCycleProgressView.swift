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

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        timer?.invalidate()
    }

    func configure(lastUpdated: Date, reading: AranetReading, updateSequence: UInt) {
        let newCycle = updateSequence != self.updateSequence
        self.updateSequence = updateSequence
        interval = Self.interval(for: reading)

        if newCycle {
            cycleAnchor = lastUpdated
            cycleStartAgo = TimeInterval(reading.ago ?? 0)
        }

        isHidden = false
        refresh()
        startTimer()
    }

    func clear() {
        cycleAnchor = nil
        cycleStartAgo = 0
        updateSequence = 0
        timer?.invalidate()
        timer = nil
        isHidden = true
        fillView.frame.size.width = 0
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutBar(progress: currentProgress())
    }

    // MARK: - Private

    private func setupSubviews() {
        trackView.wantsLayer = true
        trackView.layer?.backgroundColor = NSColor.separatorColor.cgColor
        trackView.layer?.cornerRadius = Self.cornerRadius
        trackView.layer?.masksToBounds = true
        addSubview(trackView)

        fillView.wantsLayer = true
        fillView.layer?.cornerRadius = Self.cornerRadius
        fillView.layer?.masksToBounds = true
        trackView.addSubview(fillView)

        isHidden = true
    }

    private func startTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func refresh() {
        guard let cycleAnchor else { return }

        let elapsed = cycleStartAgo + Date().timeIntervalSince(cycleAnchor)

        if elapsed >= interval * Double(degradedCycleThreshold) {
            fillView.layer?.backgroundColor = Self.darkRed.cgColor
            layoutBar(progress: 1)
        }
        else {
            let progress = cycleProgress(elapsed: elapsed)
            fillView.layer?.backgroundColor = Self.normalColor(progress: progress).cgColor
            layoutBar(progress: progress)
        }

        trackView.needsDisplay = true
        fillView.needsDisplay = true
    }

    /// Maps total elapsed time into a repeating 0...1 progress within each interval.
    private func cycleProgress(elapsed: TimeInterval) -> Double {
        let position = elapsed.truncatingRemainder(dividingBy: interval)
        return position / interval
    }

    private func currentProgress() -> Double {
        guard let cycleAnchor else { return 0 }

        let elapsed = cycleStartAgo + Date().timeIntervalSince(cycleAnchor)
        if elapsed >= interval * Double(degradedCycleThreshold) { return 1 }
        return cycleProgress(elapsed: elapsed)
    }

    private func layoutBar(progress: Double) {
        guard frame.width > 0, frame.height > 0 else { return }

        trackView.frame = bounds
        fillView.frame = NSRect(x: 0, y: 0, width: bounds.width * progress, height: bounds.height)
    }

    private static func interval(for reading: AranetReading) -> TimeInterval {
        TimeInterval(reading.interval.map { max($0, 1) } ?? UInt16(defaultInterval))
    }

    private var degradedCycleThreshold: Int {
        DegradedSituationPreferences.cycles
    }

    private static func normalColor(progress: Double) -> NSColor {
        let t = min(max(progress, 0), 1)
        let alpha = lightGreen.alphaComponent + (lightGreenFadedAlpha - lightGreen.alphaComponent) * t
        return NSColor(
            red: lightGreen.redComponent,
            green: lightGreen.greenComponent,
            blue: lightGreen.blueComponent,
            alpha: alpha
        )
    }
}
