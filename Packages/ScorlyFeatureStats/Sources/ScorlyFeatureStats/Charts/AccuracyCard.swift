import ScorlyDesignSystem
import SwiftUI

/// Composed card for fairway / green accuracy. Wind rose dominates the
/// top; the per-round percentage line at the bottom now uses the
/// taller `ChartedLine` so the trend reads as a chart, not a
/// sparkline. Same composition for FIR (L/R only) and GIR
/// (L/R/Long/Short).
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

    var body: some View {
        AccuracyRoseCard(kind: kind.sharedKind, values: sharedValues) {
            ChartedLine(series: series, format: .percent, height: 96)
        }
    }

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

    private func sharedDirection(_ direction: WindRoseData.Direction) -> AccuracyRoseValues.Direction {
        switch direction {
        case .left: .left
        case .right: .right
        case .long: .long
        case .short: .short
        }
    }
}
