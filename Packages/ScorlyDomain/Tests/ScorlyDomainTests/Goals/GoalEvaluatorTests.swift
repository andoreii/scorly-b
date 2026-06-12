import Foundation
import Testing
@testable import ScorlyDomain

struct GoalEvaluatorTests {
    // MARK: - scoreUnderOrEqual

    @Test("Score-under uses the BEST (lowest) round and inverts fraction")
    func scoreUnderOrEqualBestRound() {
        let testGoal = goal(.scoreUnderOrEqual(target: 85))
        let rounds = [round(score: 92), round(score: 88), round(score: 95)]
        let progress = GoalEvaluator.evaluate(goal: testGoal, against: rounds)
        #expect(progress.current == 88)
        #expect(progress.target == 85)
        #expect(!progress.isAchieved)
        #expect(progress.fraction > dec("0.96") && progress.fraction < dec("0.97"))
    }

    @Test("Score-under achieves at-or-below target → fraction == 1")
    func scoreUnderOrEqualAchieved() {
        let testGoal = goal(.scoreUnderOrEqual(target: 85))
        let progress = GoalEvaluator.evaluate(goal: testGoal, against: [round(score: 84)])
        #expect(progress.isAchieved)
        #expect(progress.fraction == 1)
        #expect(progress.current == 84)
    }

    @Test("Score-under against zero rounds returns zero progress")
    func scoreUnderEmpty() {
        let progress = GoalEvaluator.evaluate(
            goal: goal(.scoreUnderOrEqual(target: 85)),
            against: []
        )
        #expect(progress.current == 0)
        #expect(progress.fraction == 0)
        #expect(!progress.isAchieved)
    }

    // MARK: - handicapBelowOrEqual

    @Test("Handicap goal evaluates from differentials and treats no-data as zero")
    func handicapEvaluation() {
        // 5 rounds: WHS short-history rule uses lowest 1 of 5 with no adjustment.
        let rounds = (0..<5).map { offset in
            round(
                score: 90 + offset,
                rating: dec("72"),
                slope: dec("113"),
                holesPlayed: .eighteen
            )
        }
        let achieved = GoalEvaluator.evaluate(
            goal: goal(.handicapBelowOrEqual(target: dec("18.0"))),
            against: rounds
        )
        #expect(achieved.current == dec("18.0"))
        #expect(achieved.isAchieved)

        let unmet = GoalEvaluator.evaluate(
            goal: goal(.handicapBelowOrEqual(target: dec("10.0"))),
            against: rounds
        )
        #expect(unmet.current == dec("18.0"))
        #expect(!unmet.isAchieved)
        #expect(unmet.fraction > dec("0.55") && unmet.fraction < dec("0.56"))

        // Fewer than 3 eligible diffs means handicap is nil, so zero progress.
        let sparse = GoalEvaluator.evaluate(
            goal: goal(.handicapBelowOrEqual(target: dec("18.0"))),
            against: [rounds[0], rounds[1]]
        )
        #expect(sparse.current == 0)
        #expect(!sparse.isAchieved)
    }

    // MARK: - rate goals

    @Test("GIR rate aggregates greens / holes across the round set")
    func girRateAggregation() {
        let firstRound = round(score: 18, holeStats: [
            HoleStat(par: 3, strokes: 3, putts: 2, teeShotLie: .green), // GIR
            HoleStat(par: 3, strokes: 3, putts: 2, teeShotLie: .green), // GIR
            HoleStat(par: 4, strokes: 5, putts: 2, approachLie: .roughLeft),
            HoleStat(par: 4, strokes: 5, putts: 2, approachLie: .roughLeft),
        ])
        let secondRound = round(score: 18, holeStats: [
            HoleStat(par: 3, strokes: 3, putts: 2, teeShotLie: .green), // GIR
            HoleStat(par: 3, strokes: 4, putts: 2, teeShotLie: .roughLeft),
            HoleStat(par: 4, strokes: 5, putts: 2, approachLie: .roughLeft),
            HoleStat(par: 4, strokes: 5, putts: 2, approachLie: .roughLeft),
        ])
        let progress = GoalEvaluator.evaluate(
            goal: goal(.girRateAtLeast(target: dec("0.5"))),
            against: [firstRound, secondRound]
        )
        #expect(progress.current == dec("0.375"))
        #expect(!progress.isAchieved)
        #expect(progress.fraction == dec("0.75"))
    }

    @Test("FIR rate uses par-4+ holes as denominator (par-3 holes excluded)")
    func firRateDenominator() {
        let theRound = round(score: 18, holeStats: [
            HoleStat(par: 4, strokes: 4, putts: 2, teeShotLie: .fairway), // FIR
            HoleStat(par: 4, strokes: 4, putts: 2, teeShotLie: .fairway), // FIR
            HoleStat(par: 4, strokes: 5, putts: 2, teeShotLie: .roughLeft),
            HoleStat(par: 3, strokes: 3, putts: 2, teeShotLie: .fairway), // par-3 doesn't count
        ])
        let progress = GoalEvaluator.evaluate(
            goal: goal(.firRateAtLeast(target: dec("0.5"))),
            against: [theRound]
        )
        #expect(progress.isAchieved)
        #expect(progress.fraction == 1)
    }

    @Test("3-putt rate uses ≤ comparison and inverts fraction")
    func threePuttRateAtMost() {
        let theRound = round(score: 18, holeStats: [
            HoleStat(par: 4, strokes: 6, putts: 3),
            HoleStat(par: 4, strokes: 4, putts: 2),
            HoleStat(par: 4, strokes: 4, putts: 2),
            HoleStat(par: 4, strokes: 4, putts: 2),
        ])
        let progress = GoalEvaluator.evaluate(
            goal: goal(.threePuttRateAtMost(target: dec("0.10"))),
            against: [theRound]
        )
        #expect(progress.current == dec("0.25"))
        #expect(!progress.isAchieved)
        #expect(progress.fraction == dec("0.4"))
    }

    @Test("3-putt rate at zero (no 3-putts) is achieved")
    func threePuttRateAchieved() {
        let theRound = round(score: 18, holeStats: [
            HoleStat(par: 4, strokes: 4, putts: 2),
            HoleStat(par: 4, strokes: 4, putts: 2),
        ])
        let progress = GoalEvaluator.evaluate(
            goal: goal(.threePuttRateAtMost(target: dec("0.10"))),
            against: [theRound]
        )
        #expect(progress.current == 0)
        #expect(progress.isAchieved)
        #expect(progress.fraction == 1)
    }

    // MARK: - SG category

    @Test("SG category goal averages across rounds with sgTotals; ignores nil-SG rounds")
    func sgCategoryAveraging() {
        let withSG: [CompletedRound] = [
            roundWithSG(putt: dec("0.5")),
            roundWithSG(putt: dec("1.0")),
            roundWithSG(putt: dec("0.0")),
        ]
        let noSG = round(score: 80) // sgTotals nil, should be ignored
        let progress = GoalEvaluator.evaluate(
            goal: goal(.sgCategoryAtLeast(category: .putt, target: dec("0.4"))),
            against: withSG + [noSG]
        )
        #expect(progress.current == dec("0.5"))
        #expect(progress.isAchieved)
        #expect(progress.fraction == 1)
    }

    @Test("SG category against rounds with no SG data returns zero progress")
    func sgCategoryEmpty() {
        let progress = GoalEvaluator.evaluate(
            goal: goal(.sgCategoryAtLeast(category: .ott, target: dec("0.5"))),
            against: [round(score: 80)]
        )
        #expect(progress.current == 0)
        #expect(!progress.isAchieved)
    }

    // MARK: - roundsPlayed

    @Test("Rounds-played counts by array length and caps fraction at 1")
    func roundsPlayedCount() {
        let rounds = Array(repeating: round(score: 80), count: 7)
        let progress = GoalEvaluator.evaluate(
            goal: goal(.roundsPlayed(target: 10)),
            against: rounds
        )
        #expect(progress.current == 7)
        #expect(progress.target == 10)
        #expect(!progress.isAchieved)
        #expect(progress.fraction == dec("0.7"))

        let achieved = GoalEvaluator.evaluate(
            goal: goal(.roundsPlayed(target: 5)),
            against: rounds
        )
        #expect(achieved.isAchieved)
        #expect(achieved.fraction == 1)
    }

    // MARK: - Goal Codable

    @Test("Goal round-trips through JSON, preserving GoalKind associated values")
    func goalCodable() throws {
        let original = goal(.sgCategoryAtLeast(category: .putt, target: dec("0.5")))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Goal.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Helpers

    private func goal(_ kind: GoalKind) -> Goal {
        Goal(
            id: UUID(),
            title: "Test goal",
            kind: kind,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func round(
        score: Int,
        par: Int = 72,
        rating: Decimal? = nil,
        slope: Decimal? = nil,
        holesPlayed: HolesPlayed = .eighteen,
        holeStats: [HoleStat] = []
    ) -> CompletedRound {
        CompletedRound(
            id: UUID(),
            datePlayed: Date(timeIntervalSince1970: 0),
            par: par,
            totalScore: score,
            holesPlayed: holesPlayed,
            courseRating: rating,
            slope: slope,
            holeStats: holeStats
        )
    }

    private func roundWithSG(
        ott: Decimal = 0, app: Decimal = 0, arg: Decimal = 0, putt: Decimal = 0
    ) -> CompletedRound {
        let totals = SGTotals(ott: ott, app: app, arg: arg, putt: putt, total: ott + app + arg + putt)
        return CompletedRound(
            id: UUID(),
            datePlayed: Date(timeIntervalSince1970: 0),
            par: 72,
            totalScore: 80,
            holesPlayed: .eighteen,
            sgTotals: totals
        )
    }

    private func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: nil) ?? .nan
    }
}
