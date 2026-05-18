import Foundation
import Testing
@testable import ScorlyDomain

struct WHSCalculatorTests {
    // MARK: - differential

    @Test("Differential — canonical 18-hole calc rounds to one decimal")
    func differentialCanonical() {
        // (113 / 130) × (85 − 72.5) = 0.86923… × 12.5 = 10.86538… → 10.9
        let result = WHSCalculator.differential(
            score: 85,
            rating: dec("72.5"),
            slope: dec("130"),
            holesPlayed: .eighteen
        )
        #expect(result == dec("10.9"))
    }

    @Test("Differential — slope 113 collapses the formula to (score − rating)")
    func differentialIdentitySlope() {
        let result = WHSCalculator.differential(
            score: 80,
            rating: dec("70.0"),
            slope: dec("113"),
            holesPlayed: .eighteen
        )
        #expect(result == dec("10.0"))
    }

    @Test("Differential — score below rating yields a negative differential")
    func differentialNegative() {
        let result = WHSCalculator.differential(
            score: 68,
            rating: dec("72.0"),
            slope: dec("113"),
            holesPlayed: .eighteen
        )
        #expect(result == dec("-4.0"))
    }

    @Test("Differential — non-18-hole rounds return nil")
    func differentialRejectsShortRounds() {
        for holes: HolesPlayed in [.front9, .back9] {
            #expect(
                WHSCalculator.differential(
                    score: 42,
                    rating: dec("36.0"),
                    slope: dec("113"),
                    holesPlayed: holes
                ) == nil
            )
        }
    }

    @Test("Differential — zero or negative rating returns nil")
    func differentialRejectsZeroRating() {
        #expect(
            WHSCalculator.differential(
                score: 80, rating: 0, slope: dec("113"), holesPlayed: .eighteen
            ) == nil
        )
        #expect(
            WHSCalculator.differential(
                score: 80, rating: dec("-1"), slope: dec("113"), holesPlayed: .eighteen
            ) == nil
        )
    }

    @Test("Differential — zero or negative slope returns nil")
    func differentialRejectsZeroSlope() {
        #expect(
            WHSCalculator.differential(
                score: 80, rating: dec("72"), slope: 0, holesPlayed: .eighteen
            ) == nil
        )
        #expect(
            WHSCalculator.differential(
                score: 80, rating: dec("72"), slope: dec("-1"), holesPlayed: .eighteen
            ) == nil
        )
    }

    // MARK: - handicapIndex — insufficient history

    @Test("Index — empty / 1 / 2 differentials return nil")
    func indexInsufficientHistory() {
        #expect(WHSCalculator.handicapIndex(from: []) == nil)
        #expect(WHSCalculator.handicapIndex(from: [dec("10.0")]) == nil)
        #expect(WHSCalculator.handicapIndex(from: [dec("10.0"), dec("12.0")]) == nil)
    }

    // MARK: - handicapIndex — partial history (USGA short-history table)

    @Test("Index — 3 rounds: lowest 1 minus 2.0")
    func indexThreeRounds() {
        let diffs = [dec("10.0"), dec("12.0"), dec("14.0")]
        // lowest_1 = 10.0, − 2.0 = 8.0
        #expect(WHSCalculator.handicapIndex(from: diffs) == dec("8.0"))
    }

    @Test("Index — 4 rounds: lowest 1 minus 1.0")
    func indexFourRounds() {
        let diffs = [dec("10.0"), dec("12.0"), dec("14.0"), dec("16.0")]
        #expect(WHSCalculator.handicapIndex(from: diffs) == dec("9.0"))
    }

    @Test("Index — 5 rounds: lowest 1, no adjustment")
    func indexFiveRounds() {
        let diffs = [dec("10.0"), dec("12.0"), dec("14.0"), dec("16.0"), dec("18.0")]
        #expect(WHSCalculator.handicapIndex(from: diffs) == dec("10.0"))
    }

    @Test("Index — 6 rounds: avg(lowest 2) minus 1.0")
    func indexSixRounds() {
        let diffs = [dec("10.0"), dec("12.0"), dec("14.0"), dec("16.0"), dec("18.0"), dec("20.0")]
        // avg(10, 12) = 11.0, −1.0 = 10.0
        #expect(WHSCalculator.handicapIndex(from: diffs) == dec("10.0"))
    }

    @Test("Index — 7 rounds: avg(lowest 2)")
    func indexSevenRounds() {
        let diffs = repeating(stride(from: 10, through: 16, by: 1).map { Decimal($0) })
        // avg(10, 11) = 10.5
        #expect(WHSCalculator.handicapIndex(from: diffs) == dec("10.5"))
    }

    @Test("Index — 8 rounds: avg(lowest 2)")
    func indexEightRounds() {
        let diffs = repeating(stride(from: 10, through: 17, by: 1).map { Decimal($0) })
        // avg(10, 11) = 10.5
        #expect(WHSCalculator.handicapIndex(from: diffs) == dec("10.5"))
    }

    @Test("Index — 9, 10, 11 rounds: avg(lowest 3)")
    func indexNineToElevenRounds() {
        for size in 9...11 {
            let diffs = stride(from: 10, through: 10 + size - 1, by: 1).map { Decimal($0) }
            // avg(10, 11, 12) = 11.0
            #expect(WHSCalculator.handicapIndex(from: diffs) == dec("11.0"))
        }
    }

    @Test("Index — 12, 13, 14 rounds: avg(lowest 4)")
    func indexTwelveToFourteenRounds() {
        for size in 12...14 {
            let diffs = stride(from: 10, through: 10 + size - 1, by: 1).map { Decimal($0) }
            // avg(10..13) = 11.5
            #expect(WHSCalculator.handicapIndex(from: diffs) == dec("11.5"))
        }
    }

    @Test("Index — 15, 16 rounds: avg(lowest 5)")
    func indexFifteenToSixteenRounds() {
        for size in 15...16 {
            let diffs = stride(from: 10, through: 10 + size - 1, by: 1).map { Decimal($0) }
            // avg(10..14) = 12.0
            #expect(WHSCalculator.handicapIndex(from: diffs) == dec("12.0"))
        }
    }

    @Test("Index — 17, 18 rounds: avg(lowest 6)")
    func indexSeventeenToEighteenRounds() {
        for size in 17...18 {
            let diffs = stride(from: 10, through: 10 + size - 1, by: 1).map { Decimal($0) }
            // avg(10..15) = 12.5
            #expect(WHSCalculator.handicapIndex(from: diffs) == dec("12.5"))
        }
    }

    @Test("Index — 19 rounds: avg(lowest 7)")
    func indexNineteenRounds() {
        let diffs = stride(from: 10, through: 28, by: 1).map { Decimal($0) }
        // avg(10..16) = 13.0
        #expect(WHSCalculator.handicapIndex(from: diffs) == dec("13.0"))
    }

    // MARK: - handicapIndex — full history (20+ rounds)

    @Test("Index — 20 rounds: avg(lowest 8) × 0.96")
    func indexTwentyRounds() {
        let diffs = stride(from: 10, through: 29, by: 1).map { Decimal($0) }
        // avg(10..17) = 13.5; × 0.96 = 12.96 → 13.0
        #expect(WHSCalculator.handicapIndex(from: diffs) == dec("13.0"))
    }

    @Test("Index — 21+ rounds: only the most-recent 20 are considered")
    func indexClipsToLastTwenty() {
        // First 5 rounds are very low — would dominate if not clipped.
        let oldGood = [dec("1.0"), dec("1.0"), dec("1.0"), dec("1.0"), dec("1.0")]
        let recent = stride(from: 10, through: 29, by: 1).map { Decimal($0) }
        let combined = oldGood + recent

        let withClipping = WHSCalculator.handicapIndex(from: combined)
        let recentOnly = WHSCalculator.handicapIndex(from: recent)
        #expect(withClipping == recentOnly)
        #expect(withClipping == dec("13.0"))
    }

    @Test("Index — input order doesn't affect lowest-N selection")
    func indexOrderInsensitiveForFiveRounds() {
        let ascending = [dec("10.0"), dec("12.0"), dec("14.0"), dec("16.0"), dec("18.0")]
        let descending = Array(ascending.reversed())
        // Both should return the same value (lowest_1 = 10.0).
        #expect(
            WHSCalculator.handicapIndex(from: ascending)
                == WHSCalculator.handicapIndex(from: descending)
        )
    }

    @Test("Index — all-zero differentials yield 0.0")
    func indexAllZeros() {
        let twenty = Array(repeating: Decimal.zero, count: 20)
        #expect(WHSCalculator.handicapIndex(from: twenty) == .zero)
    }

    // MARK: - Helpers

    /// Adapter so `stride(...)` over `Int` produces `[Decimal]` cleanly.
    private func repeating(_ values: [Decimal]) -> [Decimal] {
        values
    }

    /// Parses a Decimal literal exactly. Tests assume well-formed input.
    private func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: nil) ?? .nan
    }
}
