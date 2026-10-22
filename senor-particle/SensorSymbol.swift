import AranetKit
import Cocoa

/// SF Symbols for device types and status colors, shared by the status menu and the status item.
enum SensorSymbol {
    static let scanningSymbolName = "antenna.radiowaves.left.and.right"

    static func systemName(for type: AranetDeviceType, status: AranetStatusColor?) -> String {
        switch type {
            case .aranet4:
                return Self.airQualitySymbolName(for: status)
            case .aranet2:
                return "thermometer.medium"
            case .aranetRadiation:
                return "atom"
            case .aranetRadon:
                return "humidity.fill"
            case .unknown:
                return "dot.radiowaves.left.and.right"
        }
    }

    /// The reading's status color; climate-only readings without one count as green.
    static func effectiveStatus(from reading: AranetReading?) -> AranetStatusColor? {
        guard let reading else { return nil }
        if let status = reading.status {
            return status
        }
        if reading.temperature != nil {
            return .green
        }
        if reading.humidity != nil {
            return .green
        }
        return nil
    }

    static func image(
        for type: AranetDeviceType,
        status: AranetStatusColor?,
        pointSize: CGFloat,
        weight: NSFont.Weight = .bold
    ) -> NSImage? {
        let name = Self.systemName(for: type, status: status)
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return NSImage(systemSymbolName: name, accessibilityDescription: type.name)?.withSymbolConfiguration(config)
    }

    static func scanningImage(pointSize: CGFloat, weight: NSFont.Weight = .semibold) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return NSImage(systemSymbolName: Self.scanningSymbolName, accessibilityDescription: "Scanning")?
            .withSymbolConfiguration(config)
    }

    /// Optical centering tweak for symbols whose SF Symbol alignment rect is visually off-center.
    static func alignmentOffset(for type: AranetDeviceType) -> NSSize {
        switch type {
            case .aranetRadiation:
                return NSSize(width: 0.75, height: 0)
            case .aranet4:
                return .zero
            case .aranet2:
                return .zero
            case .aranetRadon:
                return .zero
            case .unknown:
                return .zero
        }
    }

    private static func airQualitySymbolName(for status: AranetStatusColor?) -> String {
        switch status {
            case .green:
                return "aqi.low"
            case .yellow:
                return "aqi.medium"
            case .red:
                return "aqi.high"
            case .error:
                return "aqi"
            case nil:
                return "aqi"
        }
    }
}
