import Cocoa
import Sparkle

final class AboutViewController: NSViewController {
    private let updaterController: SPUStandardUpdaterController
    private let checkForUpdatesButton = NSButton(title: "Check for Updates\u{2026}", target: nil, action: nil)
    private let automaticChecksToggle = NSButton(checkboxWithTitle: "Automatically check for updates", target: nil, action: nil)
    private let automaticDownloadsToggle = NSButton(checkboxWithTitle: "Automatically download updates", target: nil, action: nil)

    override var preferredContentSize: NSSize {
        get { return self.isViewLoaded ? self.view.bounds.size : NSSize(width: 420, height: 300) }
        set {}
    }

    init(updaterController: SPUStandardUpdaterController) {
        self.updaterController = updaterController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() -> Void {
        let width: CGFloat = 420
        let height: CGFloat = 300
        let contentWidth: CGFloat = 380
        let contentHeight: CGFloat = 232

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

        let iconView = NSImageView(frame: NSRect(x: (contentWidth - 72) / 2, y: 160, width: 72, height: 72))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: self.applicationName)
        nameLabel.font = .boldSystemFont(ofSize: 18)
        nameLabel.alignment = .center
        nameLabel.frame = NSRect(x: 0, y: 132, width: contentWidth, height: 22)
        contentView.addSubview(nameLabel)

        let versionLabel = NSTextField(labelWithString: "Version \(self.marketingVersion) (\(self.buildNumber))")
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 0, y: 109, width: contentWidth, height: 18)
        contentView.addSubview(versionLabel)

        self.checkForUpdatesButton.target = self.updaterController
        self.checkForUpdatesButton.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
        self.checkForUpdatesButton.frame = NSRect(x: (contentWidth - 160) / 2, y: 70, width: 160, height: 32)
        self.checkForUpdatesButton.bind(.enabled, to: self.updaterController.updater, withKeyPath: "canCheckForUpdates")
        contentView.addSubview(self.checkForUpdatesButton)

        self.automaticChecksToggle.target = self
        self.automaticChecksToggle.action = #selector(self.automaticChecksChanged(_:))
        self.automaticChecksToggle.frame = NSRect(x: 0, y: 30, width: contentWidth, height: 22)
        contentView.addSubview(self.automaticChecksToggle)

        self.automaticDownloadsToggle.target = self
        self.automaticDownloadsToggle.action = #selector(self.automaticDownloadsChanged(_:))
        self.automaticDownloadsToggle.frame = NSRect(x: 0, y: 0, width: contentWidth, height: 22)
        contentView.addSubview(self.automaticDownloadsToggle)
    }

    override func viewWillAppear() -> Void {
        super.viewWillAppear()
        self.refreshUpdatePreferences()
    }

    deinit {
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

    private var applicationName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Se\u{00F1}or Particle"
    }

    private var marketingVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var buildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
}
