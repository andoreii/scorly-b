import Foundation
import Testing
@testable import ScorlyDomain

struct CompletedRoundTests {
    @Test("Differential delegates to WHSCalculator and returns nil without rating/slope")
    func differentialDelegation() {
        // Eligible: 18 holes, rating 72, slope 113 → (113/113) * (90 - 72) = 18.0
        let eligible = round(score: 90, rating: dec("72"), slope: dec("113"), holesPlayed: .eighteen)
        #expect(eligible.differential == dec("18.0"))

        // Missing rating → nil
        let noRating = round(score: 90, rating: nil, slope: dec("113"), holesPlayed: .eighteen)
        #expect(noRating.differential == nil)

        // Missing slope → nil
        let noSlope = round(score: 90, rating: dec("72"), slope: nil, holesPlayed: .eighteen)
        #expect(noSlope.differential == nil)

        // Front 9 → nil (WHSCalculator rejects non-18)
        let front9 = round(score: 45, rating: dec("36"), slope: dec("113"), holesPlayed: .front9)
        #expect(front9.differential == nil)
    }

    @Test("Aggregate counters reflect underlying HoleStat derivations")
    func aggregateCounters() {
        let stats: [HoleStat] = [
            // Par 4, GIR + FIR, 2 putts
            HoleStat(par: 4, strokes: 4, putts: 2, teeShotLie: .fairway, approachLie: .green),
            // Par 3 GIR (tee on green), 2 putts
            HoleStat(par: 3, strokes: 3, putts: 2, teeShotLie: .green),
            // Par 5, missed FIR, 3-putt
            HoleStat(par: 5, strokes: 7, putts: 3, teeShotLie: .roughLeft, approachLie: .roughRight),
            // Par 4, FIR but missed green, no 3-putt
            HoleStat(par: 4, strokes: 5, putts: 2, teeShotLie: .fairway, approachLie: .bunkerLeft),
        ]
        let theRound = round(score: 19, holeStats: stats)
        #expect(theRound.girCount == 2)
        #expect(theRound.firCount == 2) // par-4 fairway #1, par-4 fairway #4
        #expect(theRound.firOpportunities == 3) // par-3 doesn't count
        #expect(theRound.threePuttCount == 1)
        #expect(theRound.totalPutts == 9)
    }

    @Test("scoreVsPar is signed difference")
    func scoreVsParSign() {
        #expect(round(score: 90, par: 72).scoreVsPar == 18)
        #expect(round(score: 70, par: 72).scoreVsPar == -2)
        #expect(round(score: 72, par: 72).scoreVsPar == 0)
    }

    @Test("course external id is stored when provided and defaults to nil")
    func courseExternalIdStorage() {
        let courseExternalId = UUID()

        let withCourse = CompletedRound(
            id: UUID(),
            datePlayed: Date(timeIntervalSince1970: 0),
            par: 72,
            totalScore: 82,
            holesPlayed: .eighteen,
            courseExternalId: courseExternalId
        )

        #expect(withCourse.courseExternalId == courseExternalId)
        #expect(round(score: 82).courseExternalId == nil)
    }

    // MARK: - Helpers

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

    private func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: nil) ?? .nan
    }
}
