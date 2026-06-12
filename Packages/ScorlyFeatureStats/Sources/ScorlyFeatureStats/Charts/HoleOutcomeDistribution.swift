import ScorlyDesignSystem
import SwiftUI

/// 4-bucket hole-outcome distribution rendered as a donut chart, sharing
/// `HoleHeatGrid.colors(for:)` so a token change propagates to both.
struct HoleOutcomeDistribution: View {
    let counts: [HoleOutcome: Int]
    let total: Int

    var body: some View {
        ScoringDistributionCard(
            counts: counts.reduce(into: [:]) { result, pair in
                result[sharedOutcome(pair.key)] = pair.value
            },
            total: total
        )
    }

    private func sharedOutcome(_ outcome: HoleOutcome) -> ScoringOutcome {
        switch outcome {
        case .birdiePlus: .birdiePlus
        case .par: .par
        case .bogey: .bogey
        case .doublePlus: .doublePlus
        }
    }
}
