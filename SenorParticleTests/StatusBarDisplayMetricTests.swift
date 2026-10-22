import AranetKit
import Foundation
import Testing

@testable import senor_particle

@Suite("StatusBarDisplayMetric")
struct StatusBarDisplayMetricTests {
    @Test(
        "Values format in metric units",
        arguments: zip(
            StatusBarDisplayMetric.allCases,
            [
                "812 ppm",
                "21.5 \u{00B0}C",
                "43%",
                "1013.2 hPa",
                "0.120 \u{00B5}Sv/h",
                "1234.57 \u{00B5}Sv",
                "1.0 d",
                "148 Bq/m\u{00B3}"
            ]
        )
    )
    func metricValues(metric: StatusBarDisplayMetric, expected: String) -> Void {
        #expect(metric.valueString(for: ReadingFixtures.everything(), unitSystem: .metric) == expected)
    }

    @Test(
        "Values format in imperial units",
        arguments: zip(
            StatusBarDisplayMetric.allCases,
            [
                "812 ppm",
                "70.7 \u{00B0}F",
                "43%",
                "29.92 inHg",
                "0.012 mrem/h",
                "123.46 mrem",
                "1.0 d",
                "4.0 pCi/L"
            ]
        )
    )
    func imperialValues(metric: StatusBarDisplayMetric, expected: String) -> Void {
        #expect(metric.valueString(for: ReadingFixtures.everything(), unitSystem: .imperial) == expected)
    }

    @Test("A reading without the measurement has no value", arguments: StatusBarDisplayMetric.allCases)
    func missingMeasurement(metric: StatusBarDisplayMetric) -> Void {
        let reading = AranetReading()

        #expect(metric.isAvailable(in: reading) == false)
        #expect(metric.valueString(for: reading, unitSystem: .metric) == nil)
        #expect(metric.isAvailable(in: ReadingFixtures.everything()) == true)
    }

    @Test("Available metrics follow declaration order")
    func availableMetrics() -> Void {
        #expect(StatusBarDisplayMetric.availableMetrics(for: ReadingFixtures.aranet4()) == [.co2, .temperature, .humidity, .pressure])
        #expect(StatusBarDisplayMetric.availableMetrics(for: ReadingFixtures.radon()) == [.temperature, .humidity, .pressure, .radonConcentration])
        #expect(StatusBarDisplayMetric.availableMetrics(for: nil).isEmpty == true)
    }

    @Test("The default values are the first two available values")
    func defaultValueStrings() -> Void {
        #expect(StatusBarDisplayMetric.defaultValueStrings(for: ReadingFixtures.aranet4(), unitSystem: .metric) == ["812 ppm", "21.5 \u{00B0}C"])
        let radiationValues = StatusBarDisplayMetric.defaultValueStrings(for: ReadingFixtures.radiation(), unitSystem: .metric)
        #expect(radiationValues == ["0.120 \u{00B5}Sv/h", "1234.57 \u{00B5}Sv"])
        #expect(StatusBarDisplayMetric.defaultValueStrings(for: AranetReading(), unitSystem: .metric).isEmpty == true)
    }

    @Test("Every metric has its own label")
    func labelsAreDistinct() -> Void {
        let labels = Set(StatusBarDisplayMetric.allCases.map { $0.label })

        #expect(labels.count == StatusBarDisplayMetric.allCases.count)
    }
}
