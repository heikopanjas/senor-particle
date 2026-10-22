import Cocoa
import Sparkle

// MARK: - Toolbar identifiers

extension NSToolbarItem.Identifier {
    fileprivate static let general = NSToolbarItem.Identifier("general")
    fileprivate static let devices = NSToolbarItem.Identifier("devices")
    fileprivate static let advancedSettings = NSToolbarItem.Identifier("advancedSettings")
    fileprivate static let about = NSToolbarItem.Identifier("about")
}

// MARK: - SettingsWindowController

/// The shared Settings window with its General, Devices, Advanced, and About tabs.
final class SettingsWindowController: NSWindowController {
    private static let tabIdentifiers: [NSToolbarItem.Identifier] = [.general, .devices, .advancedSettings, .about]
    private static let initialContentSize = NSSize(width: 420, height: 72)

    private var didCenter = false
    private let generalVC: GeneralViewController
    private let devicesVC: DevicesViewController
    private let advancedSettingsVC: AdvancedSettingsViewController
    private let aboutVC: AboutViewController
    private var selectedIdentifier = NSToolbarItem.Identifier.general

    init(sensorManager: SensorManager, preferences: PreferencesStore, updaterController: SPUStandardUpdaterController) {
        self.generalVC = GeneralViewController(preferences: preferences)
        self.devicesVC = DevicesViewController(sensorManager: sensorManager, preferences: preferences)
        self.advancedSettingsVC = AdvancedSettingsViewController(preferences: preferences)
        self.aboutVC = AboutViewController(updaterController: updaterController)

        super.init(
            window: NSWindow(
                contentRect: NSRect(origin: .zero, size: Self.initialContentSize),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            ))

        guard let window = self.window else { return }
        window.title = "General"
        window.toolbarStyle = .preference
        window.contentViewController = self.generalVC

        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.delegate = self
        window.toolbar = toolbar
        toolbar.selectedItemIdentifier = .general
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showAndBringToFront() -> Void {
        if self.didCenter == false, let window = self.window, let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let width = (screenFrame.width / 2).rounded()
            let height = (screenFrame.height / 2).rounded()
            let x = (screenFrame.midX - width / 2).rounded()
            let y = (screenFrame.midY - height / 2).rounded()
            window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
            self.didCenter = true
        }
        self.showWindow(nil)
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Selects the About tab before showing the window so it never flashes the previously selected tab.
    func showAboutAndBringToFront() -> Void {
        self.switchToTab(.about)
        self.showAndBringToFront()
    }

    // MARK: - Tab switching

    @objc private func showGeneral() -> Void { self.switchToTab(.general) }
    @objc private func showDevices() -> Void { self.switchToTab(.devices) }
    @objc private func showAdvancedSettings() -> Void { self.switchToTab(.advancedSettings) }
    @objc private func showAbout() -> Void { self.switchToTab(.about) }

    /// Shows the tab's view controller; its view is loaded and sized to the current content first, so the window keeps
    /// its size instead of adopting the tab's design size.
    private func switchToTab(_ identifier: NSToolbarItem.Identifier) -> Void {
        guard identifier != self.selectedIdentifier else { return }
        guard let window = self.window else { return }
        self.selectedIdentifier = identifier
        let newViewController = self.viewController(for: identifier)
        if let contentBounds = window.contentView?.bounds {
            _ = newViewController.view
            newViewController.view.frame = contentBounds
        }
        window.contentViewController = newViewController
        window.title = self.title(for: identifier)
        window.toolbar?.selectedItemIdentifier = identifier
    }

    private func viewController(for identifier: NSToolbarItem.Identifier) -> NSViewController {
        switch identifier {
            case .general: return self.generalVC
            case .devices: return self.devicesVC
            case .advancedSettings: return self.advancedSettingsVC
            case .about: return self.aboutVC
            default: return self.generalVC
        }
    }

    private func title(for identifier: NSToolbarItem.Identifier) -> String {
        switch identifier {
            case .general: return "General"
            case .devices: return "Devices"
            case .advancedSettings: return "Advanced"
            case .about: return "About"
            default: return "Settings"
        }
    }
}

// MARK: - NSToolbarDelegate

extension SettingsWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return Self.tabIdentifiers
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return Self.tabIdentifiers
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return Self.tabIdentifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
            case .general:
                item.label = "General"
                item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
                item.action = #selector(self.showGeneral)
                item.target = self
            case .devices:
                item.label = "Devices"
                item.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Devices")
                item.action = #selector(self.showDevices)
                item.target = self
            case .advancedSettings:
                item.label = "Advanced"
                item.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Advanced")
                item.action = #selector(self.showAdvancedSettings)
                item.target = self
            case .about:
                item.label = "About"
                item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
                item.action = #selector(self.showAbout)
                item.target = self
            default:
                return nil
        }
        return item
    }
}
