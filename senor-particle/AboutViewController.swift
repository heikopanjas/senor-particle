import Cocoa
import Sparkle

/// Settings > About: app icon, name, version, and the Sparkle update controls.
final class AboutViewController: NSViewController {
    private static let designSize = NSSize(width: 420, height: 300)
    private static let contentSize = NSSize(width: 380, height: 232)
    private static let iconSize: CGFloat = 72
    private static let iconY: CGFloat = 160
    private static let nameLabelY: CGFloat = 132
    private static let nameLabelHeight: CGFloat = 22
    private static let nameFontSize: CGFloat = 18
    private static let versionLabelY: CGFloat = 109
    private static let versionLabelHeight: CGFloat = 18
    private static let updateButtonSize = NSSize(width: 160, height: 32)
    private static let updateButtonY: CGFloat = 70
    private static let toggleRowSpacing: CGFloat = 30
    private static let toggleHeight: CGFloat = 22

    private let updaterController: SPUStandardUpdaterController
    private let checkForUpdatesButton = NSButton(title: "Check for Updates\u{2026}", target: nil, action: nil)
    private let automaticChecksToggle = NSButton(checkboxWithTitle: "Automatically check for updates", target: nil, action: nil)
    private let automaticDownloadsToggle = NSButton(checkboxWithTitle: "Automatically download updates", target: nil, action: nil)

    override var preferredContentSize: NSSize {
        get { return self.isViewLoaded == true ? self.view.bounds.size : Self.designSize }
        set {}
    }

    init(updaterController: SPUStandardUpdaterController) {
        self.updaterController = updaterController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() -> Void {
        let width = Self.designSize.width
        let height = Self.designSize.height
        let contentWidth = Self.contentSize.width
        let contentHeight = Self.contentSize.height

        self.view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        let contentView = NSView(
            frame: NSRect(
                x: (width - contentWidth) / 2,
                y: (height - contentHeight) / 2,
                width: contentWidth,
                height: contentHeight
            ))
        contentView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        self.view.addSubview(contentView)

        let iconView = NSImageView(
            frame: NSRect(x: (contentWidth - Self.iconSize) / 2, y: Self.iconY, width: Self.iconSize, height: Self.iconSize)
        )
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: Bundle.main.displayName)
        nameLabel.font = .boldSystemFont(ofSize: Self.nameFontSize)
        nameLabel.alignment = .center
        nameLabel.frame = NSRect(x: 0, y: Self.nameLabelY, width: contentWidth, height: Self.nameLabelHeight)
        contentView.addSubview(nameLabel)

        let versionLabel = NSTextField(labelWithString: "Version \(self.marketingVersion) (\(self.buildNumber))")
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 0, y: Self.versionLabelY, width: contentWidth, height: Self.versionLabelHeight)
        contentView.addSubview(versionLabel)

        self.checkForUpdatesButton.target = self.updaterController
        self.checkForUpdatesButton.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        self.checkForUpdatesButton.frame = NSRect(
            origin: NSPoint(x: (contentWidth - Self.updateButtonSize.width) / 2, y: Self.updateButtonY),
            size: Self.updateButtonSize
        )
        self.checkForUpdatesButton.bind(.enabled, to: self.updaterController.updater, withKeyPath: #keyPath(SPUUpdater.canCheckForUpdates))
        contentView.addSubview(self.checkForUpdatesButton)

        self.automaticChecksToggle.target = self
        self.automaticChecksToggle.action = #selector(self.automaticChecksChanged(_:))
        self.automaticDownloadsToggle.target = self
        self.automaticDownloadsToggle.action = #selector(self.automaticDownloadsChanged(_:))

        // Center the checkboxes as one group so they stay left-aligned with each other under the centered header
        let toggles = [self.automaticChecksToggle, self.automaticDownloadsToggle]
        let toggleWidth = toggles.map { $0.fittingSize.width }.max() ?? contentWidth
        let toggleX = ((contentWidth - toggleWidth) / 2).rounded()
        for (index, toggle) in toggles.enumerated() {
            let toggleY = CGFloat(toggles.count - 1 - index) * Self.toggleRowSpacing
            toggle.frame = NSRect(x: toggleX, y: toggleY, width: toggleWidth, height: Self.toggleHeight)
            contentView.addSubview(toggle)
        }
    }

    override func viewWillAppear() -> Void {
        super.viewWillAppear()
        self.refreshUpdatePreferences()
    }

    isolated deinit {
        self.checkForUpdatesButton.unbind(.enabled)
    }

    @objc private func automaticChecksChanged(_ sender: NSButton) -> Void {
        self.updaterController.updater.automaticallyChecksForUpdates = sender.state == .on
        self.refreshUpdatePreferences()
    }

    @objc private func automaticDownloadsChanged(_ sender: NSButton) -> Void {
        self.updaterController.updater.automaticallyDownloadsUpdates = sender.state == .on
        self.refreshUpdatePreferences()
    }

    private func refreshUpdatePreferences() -> Void {
        let updater = self.updaterController.updater
        self.automaticChecksToggle.state = updater.automaticallyChecksForUpdates == true ? .on : .off
        self.automaticDownloadsToggle.state = updater.automaticallyDownloadsUpdates == true ? .on : .off
        self.automaticDownloadsToggle.isEnabled = updater.automaticallyChecksForUpdates == true
    }

    private var marketingVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}
