import Cocoa

struct StatusItemDisplayValue {
    let label: String
    let values: [String]
}

final class StatusItemDisplayView: NSView {
    private static let labelFont = NSFont.monospacedSystemFont(ofSize: 6.5, weight: .semibold)
    private static let singleValueFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    private static let stackedValueFont = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)
    private static let horizontalPadding: CGFloat = 3
    private static let labelValueGap: CGFloat = 3
    private static let labelWidth: CGFloat = 7
    private static let rowSpacing: CGFloat = 0

    private var displayValue = StatusItemDisplayValue(label: "", values: [])

    override var isFlipped: Bool { return true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    func configure(value: StatusItemDisplayValue) -> Void {
        self.displayValue = value
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) -> Void {
        super.draw(dirtyRect)

        let valueX = Self.horizontalPadding + Self.labelWidth + Self.labelValueGap
        self.drawVerticalLabel(self.displayValue.label, x: Self.horizontalPadding)
        self.drawValues(self.displayValue.values, x: valueX)
    }

    @MainActor static func requiredWidth(for value: StatusItemDisplayValue) -> CGFloat {
        guard value.values.isEmpty == false else { return 0 }

        let maxValueWidth = value.values.map { Self.valueWidth(for: $0, count: value.values.count) }.max() ?? 0
        return ceil(Self.horizontalPadding * 2 + Self.labelWidth + Self.labelValueGap + maxValueWidth)
    }

    private func drawVerticalLabel(_ label: String, x: CGFloat) -> Void {
        let characters = label.map(String.init)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.labelFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let lineHeight = Self.labelFont.ascender - Self.labelFont.descender
        let totalHeight = CGFloat(characters.count) * lineHeight
        var y = max((self.bounds.height - totalHeight) / 2, 0)

        for character in characters {
            let attributedCharacter = NSAttributedString(string: character, attributes: attributes)
            let characterSize = attributedCharacter.size()
            attributedCharacter.draw(at: NSPoint(x: x + (Self.labelWidth - characterSize.width) / 2, y: y))
            y += lineHeight
        }
    }

    private func drawValues(_ values: [String], x: CGFloat) -> Void {
        guard values.isEmpty == false else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.valueFont(for: values.count),
            .foregroundColor: NSColor.labelColor
        ]
        let attributedValues = values.map { NSAttributedString(string: $0, attributes: attributes) }
        let valueFont = Self.valueFont(for: values.count)
        let rowHeight = valueFont.ascender - valueFont.descender
        let totalHeight =
            CGFloat(attributedValues.count) * rowHeight
            + CGFloat(max(attributedValues.count - 1, 0)) * Self.rowSpacing
        var y = max((self.bounds.height - totalHeight) / 2, 0) - 0.5

        for attributedValue in attributedValues {
            attributedValue.draw(at: NSPoint(x: x, y: y))
            y += rowHeight + Self.rowSpacing
        }
    }

    private static func valueFont(for count: Int) -> NSFont {
        return count == 1 ? Self.singleValueFont : Self.stackedValueFont
    }

    private static func valueWidth(for value: String, count: Int) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.valueFont(for: count)]
        return ceil(NSAttributedString(string: value, attributes: attributes).size().width)
    }
}
