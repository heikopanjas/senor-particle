import Cocoa

/// Settings > Advanced: the degraded situation threshold of the update cycle progress bar.
final class AdvancedSettingsViewController: NSViewController {
    private static let designSize = NSSize(width: 420, height: 142)
    private static let degradedDescriptionText =
        "A degraded situation means a sensor has missed consecutive expected update cycles. "
        + "At this threshold, the progress bar turns dark red to show the reading may be stale."

    private let preferences: PreferencesStore
    private let degradedLabel = NSTextField(labelWithString: "")
    private let degradedDescription = NSTextField(wrappingLabelWithString: "")
    private let degradedSlider = NSSlider(
        value: Double(PreferencesStore.defaultDegradedCycles),
        minValue: Double(PreferencesStore.degradedCyclesRange.lowerBound),
        maxValue: Double(PreferencesStore.degradedCyclesRange.upperBound),
        target: nil,
        action: nil
    )

    override var preferredContentSize: NSSize {
        get { return self.isViewLoaded == true ? self.view.bounds.size : Self.designSize }
        set {}
    }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() -> Void {
        let width = Self.designSize.width
        let height = Self.designSize.height
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
        self.degradedSlider.numberOfTickMarks = PreferencesStore.degradedCyclesRange.count
        self.degradedSlider.allowsTickMarkValuesOnly = true
        self.degradedSlider.frame = NSRect(x: x, y: y, width: controlWidth, height: 22)
        self.degradedSlider.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(self.degradedSlider)

        y -= 8 + 44
        self.degradedDescription.frame = NSRect(x: x, y: y, width: controlWidth, height: 44)
        self.degradedDescription.autoresizingMask = [.minYMargin, .width]
        self.degradedDescription.textColor = .secondaryLabelColor
        self.degradedDescription.font = .systemFont(ofSize: 11)
        self.degradedDescription.stringValue = Self.degradedDescriptionText
        self.view.addSubview(self.degradedDescription)
    }

    override func viewWillAppear() -> Void {
        super.viewWillAppear()
        let cycles = self.preferences.degradedCycles
        self.degradedSlider.doubleValue = Double(cycles)
        self.updateDegradedLabel(cycles: cycles)
    }

    // MARK: - Actions

    @objc private func degradedSliderChanged(_ sender: NSSlider) -> Void {
        self.preferences.degradedCycles = Int(sender.doubleValue.rounded())
        self.updateDegradedLabel(cycles: self.preferences.degradedCycles)
    }

    // MARK: - Private

    private func updateDegradedLabel(cycles: Int) -> Void {
        self.degradedLabel.stringValue = "Degraded situation: \(cycles) missed update cycles"
    }
}
