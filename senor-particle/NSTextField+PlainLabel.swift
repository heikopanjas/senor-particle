import Cocoa

extension NSTextField {
    /// Configures the receiver as a non-interactive, transparent label.
    func applyPlainLabelStyle() {
        backgroundColor = .clear
        isBezeled = false
        isEditable = false
        isSelectable = false
    }
}
