import Testing
@testable import ScorlyFeatureStats

struct TrendsDashboardMetricTests {
    @Test("Dashboard metrics format FIR, GIR, and putting cards")
    func formatsSectionCards() {
        let model = TrendsModel(
            window: .twenty,
            sampleCount: 12,
            dateSpan: nil,
            avgVsPar: 4.2,
            avgVsParPrev: nil,
            bestVsPar: nil,
            worstVsPar: nil,
            avgScore: nil,
            timeline: [],
            streak: [],
            distributionHoles: 0,
            distribution: [:],
            sg: nil,
            firRate: 0.615,
            girRate: 0.444,
            puttsPerRound: 31.25,
            threePuttRate: nil,
            firSeries: [0.42, 0.62],
            girSeries: [0.50, 0.44],
            puttsSeries: [33.0, 31.25],
            threePuttSeries: [],
            penalties: [],
            penaltyMax: 0
        )

        let metrics = TrendsDashboardMetric.sectionCards(from: model)

        #expect(metrics.map(\.title) == ["FIR%", "GIR%", "Putts/r"])
        #expect(metrics.map(\.value) == ["62", "44", "31.3"])
        #expect(metrics.map(\.unit) == ["%", "%", ""])
        #expect(metrics.map(\.detail) == ["FAIRWAYS ACCURACY", "GREENS ACCURACY", "PUTTING"])
        #expect(metrics.map(\.trend) == [.improvingUp, .worseningDown, .improvingDown])
    }

    @Test("Dashboard metrics show dash for missing values")
    func missingValuesUseDash() {
        let metrics = TrendsDashboardMetric.sectionCards(from: .empty(window: .twenty))

        #expect(metrics.map(\.value) == ["-", "-", "-"])
    }

    @Test("Trend semantics keep improvement separate from arrow direction")
    func trendSemantics() {
        #expect(TrendsDashboardMetric.Trend.improvingUp.isImproving)
        #expect(TrendsDashboardMetric.Trend.improvingDown.isImproving)
        #expect(!TrendsDashboardMetric.Trend.worseningUp.isImproving)
        #expect(!TrendsDashboardMetric.Trend.worseningDown.isImproving)

        #expect(TrendsDashboardMetric.Trend.improvingUp.pointsUp)
        #expect(!TrendsDashboardMetric.Trend.improvingDown.pointsUp)
        #expect(TrendsDashboardMetric.Trend.worseningUp.pointsUp)
        #expect(!TrendsDashboardMetric.Trend.worseningDown.pointsUp)
    }
}
