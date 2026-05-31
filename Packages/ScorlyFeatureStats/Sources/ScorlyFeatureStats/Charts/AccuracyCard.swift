import Foundation
import ScorlyDesignSystem
import SwiftUI

/// Trends-tab accuracy card. Wraps the shared `AccuracyTrendCard`
/// primitive — adapts `WindRoseData` → `AccuracyRoseValues` and pairs
/// each per-round hit-rate sample with its date so the bottom-half
/// line graph can label its x-axis.
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

    /// Bridges `WindRoseData` → `AccuracyRoseValues` (the design
    /// primitive's input shape).
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

    /// Pairs every series sample with its round date. If the caller
    /// supplied mismatched counts we trim to the shorter side rather
    /// than render a misaligned chart.
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
