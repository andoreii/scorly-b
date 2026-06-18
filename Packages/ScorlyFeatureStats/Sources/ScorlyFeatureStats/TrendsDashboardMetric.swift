import Foundation

struct TrendsDashboardMetric: Equatable, Identifiable {
    enum Kind: Equatable {
        case fairways
        case greens
        case putting
    }

    enum Trend: Equatable {
        case improvingUp
        case improvingDown
        case worseningUp
        case worseningDown

        var pointsUp: Bool {
            switch self {
            case .improvingUp, .worseningUp:
                true
            case .improvingDown, .worseningDown:
                false
            }
        }

        var isImproving: Bool {
            switch self {
            case .improvingUp, .improvingDown:
                true
            case .worseningUp, .worseningDown:
                false
            }
        }
    }

    let kind: Kind
    let title: String
    let value: String
    let unit: String
    let detail: String
    let trend: Trend?

    var id: Kind {
        kind
    }

    static func sectionCards(from model: TrendsModel) -> [TrendsDashboardMetric] {
        [
            TrendsDashboardMetric(
                kind: .fairways,
                title: "FIR%",
                value: percentage(model.firRate),
                unit: "%",
                detail: "FAIRWAYS ACCURACY",
                trend: trend(series: model.firSeries, higherIsBetter: true)
            ),
            TrendsDashboardMetric(
                kind: .greens,
                title: "GIR%",
                value: percentage(model.girRate),
                unit: "%",
                detail: "GREENS ACCURACY",
                trend: trend(series: model.girSeries, higherIsBetter: true)
            ),
            TrendsDashboardMetric(
                kind: .putting,
                title: "Putts/r",
                value: decimal(model.puttsPerRound),
                unit: "",
                detail: "PUTTING",
                trend: trend(series: model.puttsSeries, higherIsBetter: false)
            ),
        ]
    }

    private static func trend(series: [Double], higherIsBetter: Bool) -> Trend? {
        guard let first = series.first, let last = series.last, first != last else { return nil }
        if last > first {
            return higherIsBetter ? .improvingUp : .worseningUp
        }
        return higherIsBetter ? .worseningDown : .improvingDown
    }

    private static func percentage(_ value: Double?) -> String {
        guard let value else { return "-" }
        return "\(Int((value * 100).rounded()))"
    }

    private static func decimal(_ value: Double?) -> String {
        guard let value else { return "-" }
        let rounded = (value * 10).rounded(.toNearestOrAwayFromZero) / 10
        return String(format: "%.1f", rounded)
    }
}
