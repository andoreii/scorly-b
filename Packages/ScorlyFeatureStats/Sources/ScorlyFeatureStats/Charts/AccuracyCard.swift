import Foundation
import ScorlyDesignSystem
import SwiftUI

/// Trends-tab accuracy card, wrapping the shared `AccuracyTrendCard`
/// primitive with `WindRoseData` → `AccuracyRoseValues` data.
struct AccuracyCard: View {
    enum Kind {
        case fairway
        case green

        var sharedKind: AccuracyRoseKind {
            switch self {
            case .fairway: .fairway
            case .green: .green
            }
        }
    }

    let kind: Kind
    let data: WindRoseData
    let series: [Double]
    let dates: [Date]
    let courseCount: Int

    var body: some View {
        AccuracyTrendCard(
            kind: kind.sharedKind,
            values: sharedValues,
            trend: trendPoints,
            courseCount: courseCount
        )
    }

    /// Bridges `WindRoseData` → `AccuracyRoseValues`.
    private var sharedValues: AccuracyRoseValues {
        AccuracyRoseValues(
            hitRate: data.hitRate,
            opportunities: data.opportunities,
            totalMisses: data.totalMisses,
            byDirection: data.byDirection.reduce(into: [:]) { result, pair in
                result[sharedDirection(pair.key)] = AccuracyRoseValues.DirectionStack(
                    clean: pair.value.clean,
                    bunker: pair.value.bunker,
                    water: pair.value.water,
                    ob: pair.value.ob
                )
            }
        )
    }

    /// Pairs each series sample with its round date, trimming to the
    /// shorter side if counts don't match.
    private var trendPoints: [AccuracyTrendPoint] {
        let count = min(series.count, dates.count)
        return (0..<count).map { i in
            AccuracyTrendPoint(date: dates[i], hitRate: series[i])
        }
    }

    private func sharedDirection(_ direction: WindRoseData.Direction)
        -> AccuracyRoseValues.Direction
    {
        switch direction {
        case .left: .left
        case .right: .right
        case .long: .long
        case .short: .short
        }
    }
}
