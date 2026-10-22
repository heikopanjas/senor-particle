import Cocoa

/// The editable name cell of the Devices tab, remembering which device it renames.
final class DeviceNameTextField: NSTextField {
    var deviceId: UUID?
}
