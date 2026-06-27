import AranetKit
import Cocoa
import ServiceManagement

// MARK: - Degraded situation preferences

enum DegradedSituationPreferences {
    static let key = "degradedSituationCycles"
    static let defaultCycles = 3
    static let minimumCycles = 1
    static let maximumCycles = 10

    static var cycles: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.key)
            if stored < Self.minimumCycles { return Self.defaultCycles }
            return min(stored, Self.maximumCycles)
        }
        set {
            UserDefaults.standard.set(min(max(newValue, Self.minimumCycles), Self.maximumCycles), forKey: Self.key)
        }
    }
}

// MARK: - Notification preferences

enum NotificationPreferences {
    static func isEnabled(for deviceId: UUID) -> Bool {
        return UserDefaults.standard.bool(forKey: "notifications.\(deviceId.uuidString)")
    }

    static func setEnabled(_ enabled: Bool, for deviceId: UUID) -> Void {
        UserDefaults.standard.set(enabled, forKey: "notifications.\(deviceId.uuidString)")
    }
}

// MARK: - Device name preferences

enum DeviceNamePreferences {
    static func name(for deviceId: UUID) -> String? {
        return UserDefaults.standard.string(forKey: "deviceName.\(deviceId.uuidString)")
    }

    static func setName(_ name: String, for deviceId: UUID) -> Void {
        if name.isEmpty == true {
            UserDefaults.standard.removeObject(forKey: "deviceName.\(deviceId.uuidString)")
        }
        else {
            UserDefaults.standard.set(name, forKey: "deviceName.\(deviceId.uuidString)")
        }
    }
}

// MARK: - Toolbar identifiers

extension NSToolbarItem.Identifier {
    fileprivate static let general = NSToolbarItem.Identifier("general")
    fileprivate static let devices = NSToolbarItem.Identifier("devices")
    fileprivate static let advancedSettings = NSToolbarItem.Identifier("advancedSettings")
}

// MARK: - SettingsWindowController

class SettingsWindowController: NSWindowController {
    private var didCenter = false
    private let generalVC: GeneralViewController
    private let devicesVC: DevicesViewController
    private let advancedSettingsVC: AdvancedSettingsViewController
    private var selectedIdentifier = NSToolbarItem.Identifier.general

    init(sensorManager: SensorManager) {
        self.generalVC = GeneralViewController()
        self.devicesVC = DevicesViewController(sensorManager: sensorManager)
        self.advancedSettingsVC = AdvancedSettingsViewController()

        super.init(
            window: NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 72),
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

    // MARK: - Tab switching

    @objc private func showGeneral() -> Void { self.switchToTab(.general) }
    @objc private func showDevices() -> Void { self.switchToTab(.devices) }
    @objc private func showAdvancedSettings() -> Void { self.switchToTab(.advancedSettings) }

    private func switchToTab(_ identifier: NSToolbarItem.Identifier) -> Void {
        guard identifier != self.selectedIdentifier, let window = self.window else { return }
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
            default: return self.generalVC
        }
    }

    private func title(for identifier: NSToolbarItem.Identifier) -> String {
        switch identifier {
            case .general: return "General"
            case .devices: return "Devices"
            case .advancedSettings: return "Advanced"
            default: return "Settings"
        }
    }
}

// MARK: - NSToolbarDelegate

extension SettingsWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .devices, .advancedSettings]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .devices, .advancedSettings]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.general, .devices, .advancedSettings]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
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
            default:
                return nil
        }
        return item
    }
}
