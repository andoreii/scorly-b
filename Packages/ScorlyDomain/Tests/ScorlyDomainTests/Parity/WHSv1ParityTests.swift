import Foundation
import Testing
@testable import ScorlyDomain

/// Pins the v2 (USGA spec) handicap calc against v1's algorithm, which
/// always applies 0.96 to all-time lowest-N differentials.
struct WHSv1ParityTests {
    // MARK: - 15-round synthetic history

    /// Mix of "normal" and "good" rounds so the lowest-5 selection
    /// (USGA short-history rule for 15-16 rounds) is non-trivial.
    private let synthetic15: [Decimal] = [
        dec("18.4"), dec("16.2"), dec("21.1"), dec("19.8"), dec("17.5"),
        dec("15.9"), dec("20.3"), dec("18.0"), dec("22.6"), dec("19.2"),
        dec("17.7"), dec("16.5"), dec("18.9"), dec("20.0"), dec("17.1"),
    ]

    @Test("v2 handicap on 15 rounds = average of lowest 5 (no 0.96 adjust)")
    func fifteenRoundIndex() {
        // 15 rounds -> lowest 5, no adjustment, avg 16.64 rounds to 16.6.
        let index = WHSCalculator.handicapIndex(from: synthetic15)
        #expect(index == dec("16.6"))
    }

    @Test("v1 algorithm on the same 15 rounds diverges (× 0.96 applied)")
    func v1AlgorithmDiverges() {
        // v1 multiplies by 0.96 and rounds down, giving 15.9 vs v2's 16.6.
        let v1 = simulateV1HandicapIndex(from: synthetic15)
        #expect(v1 == dec("15.9"))
        #expect(WHSCalculator.handicapIndex(from: synthetic15) == dec("16.6"))
        let v2 = WHSCalculator.handicapIndex(from: synthetic15) ?? .nan
        let delta = abs(v2 - (v1 ?? .nan))
        #expect(delta > dec("0.5"))
    }

    // MARK: - 20-round case (v1 and v2 agree modulo rounding)

    @Test("At 20 rounds v2 = avg(lowest 8) × 0.96, banker's rounding to 1dp")
    func twentyRoundIndex() {
        let twenty: [Decimal] = (0..<20).map { Decimal(15 + $0) } // 15…34
        // lowest 8 avg 18.5 * 0.96 = 17.76; v2 rounds plain to 17.8.
        let index = WHSCalculator.handicapIndex(from: twenty)
        #expect(index == dec("17.8"))

        // v1 rounds the same 17.76 down to 17.7 -- within 0.1 of v2.
        let v1 = simulateV1HandicapIndex(from: twenty)
        #expect(v1 == dec("17.7"))
        let delta = abs(dec("17.8") - (v1 ?? .nan))
        #expect(delta <= dec("0.1"))
    }

    // MARK: - Manual-pull verification scaffold

    /// Placeholder until real v1 round history can be pulled in.
    @Test("Live-data verification scaffold (no-op until Phase C feeds it)")
    func liveDataScaffold() {
        let pulledV1Differentials: [Decimal] = [] // populate post-Phase-C
        guard !pulledV1Differentials.isEmpty else {
            return
        }
        let expectedV1DisplayedIndex: Decimal = 0 // populate post-Phase-C
        let v2 = WHSCalculator.handicapIndex(from: pulledV1Differentials) ?? .nan
        let delta = abs(v2 - expectedV1DisplayedIndex)
        #expect(delta <= dec("1.0"))
    }

    // MARK: - v1 algorithm reimplementation

    // Reimplemented in Decimal to avoid Double drift in expectations.
    private func simulateV1HandicapIndex(from differentials: [Decimal]) -> Decimal? {
        let sorted = differentials.sorted()
        guard sorted.count >= 3 else { return nil }
        let countToUse: Int
        switch sorted.count {
        case 3...5: countToUse = 1
        case 6...8: countToUse = 2
        case 9...11: countToUse = 3
        case 12...14: countToUse = 4
        case 15...16: countToUse = 5
        case 17...18: countToUse = 6
        case 19: countToUse = 7
        default: countToUse = 8
        }
        let lowest = Array(sorted.prefix(countToUse))
        let sum = lowest.reduce(Decimal(0), +)
        let avg = sum / Decimal(countToUse)
        let raw = avg * dec("0.96")
        // v1 rounds down to 1dp, not the nearest.
        var scaled = raw * 10
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .down)
        return rounded / 10
    }

    // MARK: - Helper

    private static func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: nil) ?? .nan
    }

    private func dec(_ value: String) -> Decimal {
        Self.dec(value)
    }
}

private func dec(_ value: String) -> Decimal {
    Decimal(string: value, locale: nil) ?? .nan
}
