import Cocoa

class AdvancedSettingsViewController: NSViewController {
    private let degradedLabel = NSTextField(labelWithString: "")
    private let degradedDescription = NSTextField(wrappingLabelWithString: "")
    private let degradedSlider = NSSlider(
        value: Double(DegradedSituationPreferences.defaultCycles),
        minValue: Double(DegradedSituationPreferences.minimumCycles),
        maxValue: Double(DegradedSituationPreferences.maximumCycles),
        target: nil,
        action: nil
    )

    override var preferredContentSize: NSSize {
        get { return self.isViewLoaded ? self.view.bounds.size : NSSize(width: 420, height: 142) }
        set {}
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() -> Void {
        let width: CGFloat = 420
        let height: CGFloat = 142
        let x: CGFloat = 20
        let controlWidth = width - 2 * x
        var y = height - 20 - 16

        self.view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        self.degradedLabel.frame = NSRect(x: x, y: y, width: controlWidth, height: 16)
        self.degradedLabel.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(self.degradedLabel)

        y -= 4 + 22
        self.degradedSlider.target = self
        self.degradedSlider.action = #selector(self.degradedSliderChanged(_:))
        self.degradedSlider.numberOfTickMarks = DegradedSituationPreferences.maximumCycles
        self.degradedSlider.allowsTickMarkValuesOnly = true
        self.degradedSlider.frame = NSRect(x: x, y: y, width: controlWidth, height: 22)
        self.degradedSlider.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(self.degradedSlider)

        y -= 8 + 44
        self.degradedDescription.frame = NSRect(x: x, y: y, width: controlWidth, height: 44)
        self.degradedDescription.autoresizingMask = [.minYMargin, .width]
        self.degradedDescription.textColor = .secondaryLabelColor
        self.degradedDescription.font = .systemFont(ofSize: 11)
        self.degradedDescription.stringValue =
            "A degraded situation means a sensor has missed consecutive expected update cycles. At this threshold, the progress bar turns dark red to show the reading may be stale."
        self.view.addSubview(self.degradedDescription)
    }

    override func viewWillAppear() -> Void {
        super.viewWillAppear()
        let cycles = DegradedSituationPreferences.cycles
        self.degradedSlider.doubleValue = Double(cycles)
        self.updateDegradedLabel(cycles: cycles)
    }

    // MARK: - Actions

    @objc private func degradedSliderChanged(_ sender: NSSlider) -> Void {
        let cycles = Int(sender.doubleValue.rounded())
        DegradedSituationPreferences.cycles = cycles
        self.updateDegradedLabel(cycles: cycles)
    }

    // MARK: - Private

    private func updateDegradedLabel(cycles: Int) -> Void {
        self.degradedLabel.stringValue = "Degraded situation: \(cycles) missed update cycles"
    }
}
