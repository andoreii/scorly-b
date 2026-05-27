import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Multi-round Strokes Gained card. Reuses the existing
/// `StrokesGainedCard` design-system primitive with the compact Trends
/// summary presentation and averaged-per-round category values.
///
/// Caller hands us the eligible filtered rounds; we do the averaging
/// and cumulative math here. Boundary mapping (`SGTotals` →
/// `SGCardValues`) mirrors the convention in Round Detail.
struct MultiRoundSGCard: View {
    let rounds: [CompletedRound]

    var body: some View {
        // The cumulative timeline section is intentionally omitted on
        // the Trend page — multi-round cumulative SG doesn't read as
        // well as the same chart does intra-round on Round Detail.
        // Hero + 4 category rows + summary footer only.
        StrokesGainedCard(
            meta: "LAST \(eligibleCount) ROUNDS · 4 CATEGORIES",
            total: averagedTotals(),
            holes: nil,
            seasonAverages: nil,
            summaryStyle: .categoryExtremes,
            breakdownDensity: .spacious
        )
    }

    private var eligibleCount: Int {
        rounds.compactMap(\.sgTotals).count
    }

    /// Average each SG category across every round that recorded SG.
    /// Returns nil when the window has no SG-enabled rounds — that
    /// fires the design-system card's placeholder branch.
    private func averagedTotals() -> SGCardValues? {
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
        return SGCardValues(
            ott: ott,
            app: app,
            arg: arg,
            putt: putt,
            total: ott + app + arg + putt
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
