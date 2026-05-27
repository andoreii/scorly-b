import ScorlyDesignSystem
import SwiftUI

/// Make % by distance bucket — one horizontal bar per bucket. Bar fill
/// is `sgPos` blended to the make rate; the right label carries the
/// percentage and attempted count in tabular mono.
struct MakePctByDistanceCard: View {
    let stats: [PuttBucket: PuttMakeStat]

    var body: some View {
        PuttMakeRateCard(stats: sharedStats)
    }

    private var sharedStats: [PuttDistanceBucket: PuttMakeValues] {
        stats.reduce(into: [:]) { result, pair in
            result[sharedBucket(pair.key)] = PuttMakeValues(
                made: pair.value.made,
                attempted: pair.value.attempted
            )
        }
    }

    private func sharedBucket(_ bucket: PuttBucket) -> PuttDistanceBucket {
        switch bucket {
        case .feet0to3: .feet0to3
        case .feet4to6: .feet4to6
        case .feet7to10: .feet7to10
        case .feet11to15: .feet11to15
        case .feet16to20: .feet16to20
        case .feet21to30: .feet21to30
        case .feet31plus: .feet31plus
        }
    }
}
