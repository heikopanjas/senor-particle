import AranetKit
import Cocoa

/// A thin bar under each device in the status menu showing how far the device is into its update interval.
///
/// The fill fades from opaque to faded light green during each interval and turns dark red once the device has missed
/// the configured number of updates. `UpdateCycleCalculator` holds the arithmetic; a new `updateSequence` re-anchors it.
final class UpdateCycleProgressView: NSView {
    private static let refreshInterval: TimeInterval = 1
    private static let cornerRadius: CGFloat = 1
    private static let lightGreen = NSColor(red: 0.20, green: 0.78, blue: 0.28, alpha: 1.0)
    private static let lightGreenFadedAlpha: CGFloat = 0.37
    private static let darkRed = NSColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1.0)

    private let trackView = NSView()
    private let fillView = NSView()
    private let now: () -> Date
    private var calculator: UpdateCycleCalculator?
    private var updateSequence: UInt = 0
    private var timer: Timer?

    override var isFlipped: Bool { return true }

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
        super.init(frame: .zero)
        self.setupSubviews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    isolated deinit {
        self.timer?.invalidate()
    }

    /// Shows the cycle of `reading`, keeping the current anchor unless `updateSequence` announces a new reading.
    func configure(lastUpdated: Date, reading: AranetReading, updateSequence: UInt, degradedCycles: Int) -> Void {
        let isNewCycle = updateSequence != self.updateSequence
        self.updateSequence = updateSequence

        let current = UpdateCycleCalculator(anchor: lastUpdated, reading: reading, degradedCycles: degradedCycles)
        if isNewCycle == true {
            self.calculator = current
        }
        else if let previous = self.calculator {
            self.calculator = UpdateCycleCalculator(
                anchor: previous.anchor,
                startAgo: previous.startAgo,
                interval: current.interval,
                degradedCycles: degradedCycles
            )
        }
        else {
            self.calculator = current
        }

        self.isHidden = false
        self.refresh()
        self.startTimer()
    }

    func clear() -> Void {
        self.calculator = nil
        self.updateSequence = 0
        self.timer?.invalidate()
        self.timer = nil
        self.isHidden = true
        self.fillView.frame.size.width = 0
    }

    override func setFrameSize(_ newSize: NSSize) -> Void {
        super.setFrameSize(newSize)
        self.layoutBar(fillFraction: self.currentState()?.fillFraction ?? 0)
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

    /// Starts the once-per-second refresh unless it already runs; `clear()` stops it.
    private func startTimer() -> Void {
        guard self.timer == nil else { return }
        self.timer = MainRunLoopTimer.scheduleRepeating(every: Self.refreshInterval) { [weak self] in
            self?.refresh()
        }
    }

    private func currentState() -> UpdateCycleCalculator.State? {
        return self.calculator?.state(at: self.now())
    }

    private func refresh() -> Void {
        guard let state = self.currentState() else { return }

        switch state {
            case .degraded:
                self.fillView.layer?.backgroundColor = Self.darkRed.cgColor
            case .progressing(let fraction):
                self.fillView.layer?.backgroundColor = Self.normalColor(fillFraction: fraction).cgColor
        }
        self.layoutBar(fillFraction: state.fillFraction)

        self.trackView.needsDisplay = true
        self.fillView.needsDisplay = true
    }

    private func layoutBar(fillFraction: Double) -> Void {
        guard self.frame.width > 0 else { return }
        guard self.frame.height > 0 else { return }

        self.trackView.frame = self.bounds
        self.fillView.frame = NSRect(x: 0, y: 0, width: self.bounds.width * fillFraction, height: self.bounds.height)
    }

    /// Light green that fades from opaque at the start of an interval to `lightGreenFadedAlpha` at its end.
    private static func normalColor(fillFraction: Double) -> NSColor {
        let fraction = min(max(fillFraction, 0), 1)
        let alpha = Self.lightGreen.alphaComponent + (Self.lightGreenFadedAlpha - Self.lightGreen.alphaComponent) * fraction
        return Self.lightGreen.withAlphaComponent(alpha)
    }
}
