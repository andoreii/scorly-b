import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Multi-round Strokes Gained card. Reuses `StrokesGainedCard` with the
/// compact Trends summary and averaged-per-round category values.
struct MultiRoundSGCard: View {
    let rounds: [CompletedRound]
    let baselineRounds: [CompletedRound]
    let comparisonReference: SGComparisonReference

    var body: some View {
        let projection = SGReferenceProjection.project(
            reference: comparisonReference,
            totals: averagedTotals(),
            holes: nil,
            baselineRounds: baselineRounds
        )
        // No cumulative timeline here — it only reads well intra-round.
        StrokesGainedCard(
            meta: "LAST \(eligibleCount) ROUNDS · 4 CATEGORIES",
            total: projection.totals.map(cardValues),
            holes: nil,
            seasonAverages: nil,
            referenceLabel: projection.referenceLabel,
            summaryStyle: .categoryExtremes,
            breakdownDensity: .spacious
        )
    }

    private var eligibleCount: Int {
        rounds.compactMap(\.sgTotals).count
    }

    /// Averages each SG category across rounds that recorded SG; nil if none did.
    private func averagedTotals() -> SGTotals? {
        let totals = rounds.compactMap(\.sgTotals)
        guard !totals.isEmpty else { return nil }
        let count = Decimal(totals.count)
        let sum = totals.reduce(into: SGSums()) { acc, totals in
            acc.ott += totals.value(for: .ott)
            acc.app += totals.value(for: .app)
            acc.arg += totals.value(for: .arg)
            acc.putt += totals.value(for: .putt)
        }
        let avg: (Decimal) -> Decimal = { $0 / count }
        let ott = avg(sum.ott)
        let app = avg(sum.app)
        let arg = avg(sum.arg)
        let putt = avg(sum.putt)
        return SGTotals(
            ott: ott,
            app: app,
            arg: arg,
            putt: putt,
            total: ott + app + arg + putt
        )
    }

    private func cardValues(_ totals: SGTotals) -> SGCardValues {
        SGCardValues(
            ott: totals.ott,
            app: totals.app,
            arg: totals.arg,
            putt: totals.putt,
            total: totals.total
        )
    }
}

// MARK: - Accumulator

private struct SGSums {
    var ott: Decimal = 0
    var app: Decimal = 0
    var arg: Decimal = 0
    var putt: Decimal = 0
}
