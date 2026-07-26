import Cocoa

extension NSTextField {
    /// Configures the receiver as a non-interactive, transparent label.
    func applyPlainLabelStyle() -> Void {
        self.backgroundColor = .clear
        self.isBezeled = false
        self.isEditable = false
        self.isSelectable = false
    }
}
