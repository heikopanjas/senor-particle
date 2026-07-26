import AranetKit
import Cocoa

enum SensorSymbol {
    static let scanningSymbolName = "antenna.radiowaves.left.and.right"

    static func systemName(for type: AranetDeviceType, status: AranetStatusColor?) -> String {
        switch type {
            case .aranet4:
                switch status {
                    case .green: return "aqi.low"
                    case .yellow: return "aqi.medium"
                    case .red: return "aqi.high"
                    default: return "aqi"
                }
            case .aranet2: return "thermometer.medium"
            case .aranetRadiation: return "atom"
            case .aranetRadon: return "humidity.fill"
            case .unknown: return "dot.radiowaves.left.and.right"
        }
    }

    static func effectiveStatus(from reading: AranetReading?) -> AranetStatusColor? {
        guard let reading else { return nil }
        if let status = reading.status { return status }
        if reading.temperature != nil || reading.humidity != nil { return .green }
        return nil
    }

    static func image(
        for type: AranetDeviceType,
        status: AranetStatusColor?,
        pointSize: CGFloat,
        weight: NSFont.Weight = .bold
    ) -> NSImage? {
        let name = systemName(for: type, status: status)
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return NSImage(systemSymbolName: name, accessibilityDescription: type.name)?.withSymbolConfiguration(config)
    }

    static func scanningImage(pointSize: CGFloat, weight: NSFont.Weight = .semibold) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return NSImage(systemSymbolName: scanningSymbolName, accessibilityDescription: "Scanning")?
            .withSymbolConfiguration(config)
    }

    /// Optical centering tweak for symbols whose SF Symbol alignment rect is visually off-center.
    static func alignmentOffset(for type: AranetDeviceType) -> NSSize {
        switch type {
            case .aranetRadiation: return NSSize(width: 0.75, height: 0)
            default: return .zero
        }
    }
}
