import Cocoa
import ServiceManagement

class GeneralViewController: NSViewController {
    private let loginToggle = NSButton(checkboxWithTitle: "Start at Login", target: nil, action: nil)
    private let personalityPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let unitSystemControl = NSSegmentedControl(
        labels: DisplayUnitSystem.allCases.map(\.displayName),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let timeoutLabel = NSTextField(labelWithString: "")
    private let timeoutSlider = NSSlider(value: ScanPreferences.defaultTimeout, minValue: 10, maxValue: 60, target: nil, action: nil)

    override var preferredContentSize: NSSize {
        get { return self.isViewLoaded ? self.view.bounds.size : NSSize(width: 420, height: 390) }
        set {}
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() -> Void {
        let width: CGFloat = 420
        let height: CGFloat = 390
        let x: CGFloat = 20
        let controlWidth = width - 2 * x
        let descriptionHeight: CGFloat = 28
        var y = height - 20 - 22

        self.view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        self.loginToggle.target = self
        self.loginToggle.action = #selector(self.toggleLogin(_:))
        self.loginToggle.frame = NSRect(x: x, y: y, width: controlWidth, height: 22)
        self.loginToggle.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(self.loginToggle)

        y -= 4 + descriptionHeight
        self.addDescription(
            "Open Se\u{00F1}or Particle automatically after you sign in to macOS.",
            x: x,
            y: y,
            width: controlWidth,
            height: descriptionHeight
        )

        y -= 16 + 16
        let personalityLabel = NSTextField(labelWithString: "Notification Personality")
        personalityLabel.frame = NSRect(x: x, y: y, width: controlWidth, height: 16)
        personalityLabel.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(personalityLabel)

        y -= 4 + 26
        self.personalityPopup.autoresizingMask = [.minYMargin, .width]
        for personality in NotificationPersonality.allCases {
            self.personalityPopup.addItem(withTitle: personality.displayName)
        }
        self.personalityPopup.target = self
        self.personalityPopup.action = #selector(self.personalityChanged(_:))
        self.personalityPopup.frame = NSRect(x: x, y: y, width: controlWidth, height: 26)
        self.view.addSubview(self.personalityPopup)

        y -= 4 + descriptionHeight
        self.addDescription(
            "Controls the tone of status notifications when sensor health changes.",
            x: x,
            y: y,
            width: controlWidth,
            height: descriptionHeight
        )

        y -= 16 + 16
        let unitSystemLabel = NSTextField(labelWithString: "Units")
        unitSystemLabel.frame = NSRect(x: x, y: y, width: controlWidth, height: 16)
        unitSystemLabel.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(unitSystemLabel)

        y -= 4 + 24
        self.unitSystemControl.target = self
        self.unitSystemControl.action = #selector(self.unitSystemChanged(_:))
        self.unitSystemControl.frame = NSRect(x: x, y: y, width: controlWidth, height: 24)
        self.unitSystemControl.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(self.unitSystemControl)

        y -= 4 + descriptionHeight
        self.addDescription(
            "Controls how temperature, pressure, radiation, and radon values are displayed.",
            x: x,
            y: y,
            width: controlWidth,
            height: descriptionHeight
        )

        y -= 16 + 16
        self.timeoutLabel.frame = NSRect(x: x, y: y, width: controlWidth, height: 16)
        self.timeoutLabel.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(self.timeoutLabel)

        y -= 4 + 22
        self.timeoutSlider.target = self
        self.timeoutSlider.action = #selector(self.sliderChanged(_:))
        self.timeoutSlider.numberOfTickMarks = 51
        self.timeoutSlider.allowsTickMarkValuesOnly = true
        self.timeoutSlider.frame = NSRect(x: x, y: y, width: controlWidth, height: 22)
        self.timeoutSlider.autoresizingMask = [.minYMargin, .width]
        self.view.addSubview(self.timeoutSlider)

        y -= 4 + descriptionHeight
        self.addDescription(
            "How long a scan waits for nearby sensors before showing the results.",
            x: x,
            y: y,
            width: controlWidth,
            height: descriptionHeight
        )
    }

    override func viewWillAppear() -> Void {
        super.viewWillAppear()
        self.loginToggle.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let timeout = ScanPreferences.timeout
        self.timeoutSlider.doubleValue = timeout
        self.updateTimeoutLabel(seconds: timeout)

        let personality = NotificationPersonalityPreferences.current
        if let index = NotificationPersonality.allCases.firstIndex(of: personality) {
            self.personalityPopup.selectItem(at: index)
        }

        let unitSystem = DisplayUnitSystemPreferences.current
        if let index = DisplayUnitSystem.allCases.firstIndex(of: unitSystem) {
            self.unitSystemControl.selectedSegment = index
        }
    }

    // MARK: - Actions

    @objc private func personalityChanged(_ sender: NSPopUpButton) -> Void {
        let index = sender.indexOfSelectedItem
        guard NotificationPersonality.allCases.indices.contains(index) == true else { return }
        NotificationPersonalityPreferences.current = NotificationPersonality.allCases[index]
    }

    @objc private func unitSystemChanged(_ sender: NSSegmentedControl) -> Void {
        let index = sender.selectedSegment
        guard DisplayUnitSystem.allCases.indices.contains(index) == true else { return }
        DisplayUnitSystemPreferences.current = DisplayUnitSystem.allCases[index]
    }

    @objc private func toggleLogin(_ sender: NSButton) -> Void {
        let enable = sender.state == .on
        do {
            if enable == true {
                try SMAppService.mainApp.register()
            }
            else {
                try SMAppService.mainApp.unregister()
            }
        }
        catch {
            NSLog("[Settings] Start at Login toggle failed: %@", error.localizedDescription)
            self.loginToggle.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    @objc private func sliderChanged(_ sender: NSSlider) -> Void {
        let value = sender.doubleValue
        ScanPreferences.storedTimeout = value
        self.updateTimeoutLabel(seconds: value)
    }

    // MARK: - Private

    private func updateTimeoutLabel(seconds: Double) -> Void {
        self.timeoutLabel.stringValue = "Scan timeout: \(Int(seconds))s"
    }

    @discardableResult
    private func addDescription(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.frame = NSRect(x: x, y: y, width: width, height: height)
        field.autoresizingMask = [.minYMargin, .width]
        field.textColor = .secondaryLabelColor
        field.font = .systemFont(ofSize: 11)
        self.view.addSubview(field)
        return field
    }
}
