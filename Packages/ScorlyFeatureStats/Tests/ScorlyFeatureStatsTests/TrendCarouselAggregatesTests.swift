import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyFeatureStats

struct TrendCarouselAggregatesTests {
    // MARK: - Putt bucketing

    @Test("Putt distance bucketing is right-closed and inclusive")
    func puttBucketing() {
        #expect(PuttBucket.bucket(forFeet: 0) == .feet0to3)
        #expect(PuttBucket.bucket(forFeet: 3) == .feet0to3)
        #expect(PuttBucket.bucket(forFeet: 4) == .feet4to6)
        #expect(PuttBucket.bucket(forFeet: 10) == .feet7to10)
        #expect(PuttBucket.bucket(forFeet: 30) == .feet21to30)
        #expect(PuttBucket.bucket(forFeet: 31) == .feet31plus)
        #expect(PuttBucket.bucket(forFeet: 99) == .feet31plus)
    }

    // MARK: - Hole outcome buckets

    @Test("HoleOutcome.outcome collapses 5-bucket distribution into 4")
    func outcomeBuckets() {
        #expect(HoleOutcome.outcome(forVsPar: -2) == .birdiePlus)
        #expect(HoleOutcome.outcome(forVsPar: -1) == .birdiePlus)
        #expect(HoleOutcome.outcome(forVsPar: 0) == .par)
        #expect(HoleOutcome.outcome(forVsPar: 1) == .bogey)
        #expect(HoleOutcome.outcome(forVsPar: 2) == .doublePlus)
        #expect(HoleOutcome.outcome(forVsPar: 4) == .doublePlus)
    }

    // MARK: - Fairway rose

    @Test("Fairway rose only counts par 4+ holes; FIR rate excludes par 3")
    func fairwayRosePar3Exclusion() {
        let rounds = [
            roundWith(
                par: 71,
                holes: [
                    // Par 3 — shouldn't contribute to FIR opportunities.
                    hole(par: 3, strokes: 3, putts: 2, teeLie: .green),
                    // Par 4 hit fairway.
                    hole(par: 4, strokes: 4, putts: 2, teeLie: .fairway),
                    // Par 4 missed left.
                    hole(par: 4, strokes: 5, putts: 2, teeLie: .roughLeft),
                ]
            ),
        ]
        let aggregates = TrendCarouselAggregates.build(
            eligible: rounds,
            allRounds: rounds
        )
        // Two opportunities (both par 4s), one hit.
        #expect(aggregates.fairwayRose.opportunities == 2)
        #expect(aggregates.fairwayRose.hitRate == 0.5)
        #expect(aggregates.fairwayRose.totalMisses == 1)
    }

    @Test("Green rose buckets miss direction by approach lie on par 4+")
    func greenRoseDirection() {
        let rounds = [
            roundWith(
                par: 36,
                holes: [
                    // Hit green.
                    hole(par: 4, strokes: 4, putts: 2, teeLie: .fairway, approachLie: .green),
                    // Missed long.
                    hole(par: 4, strokes: 5, putts: 2, teeLie: .fairway, approachLie: .recoveryLong),
                    // Missed right (bunker).
                    hole(par: 4, strokes: 5, putts: 1, teeLie: .fairway, approachLie: .bunkerRight),
                ]
            ),
        ]
        let aggregates = TrendCarouselAggregates.build(
            eligible: rounds,
            allRounds: rounds
        )
        let rose = aggregates.greenRose
        #expect(rose.opportunities == 3)
        #expect(rose.totalMisses == 2)
        #expect(rose.byDirection[.long]?.total == 1)
        #expect(rose.byDirection[.right]?.bunker == 1)
    }

    // MARK: - Make percentage

    @Test("Make-pct buckets by first putt distance; last putt counts as made")
    func makePctBuckets() {
        let hole = HoleStat(
            par: 4,
            strokes: 5,
            putts: 2,
            teeShotLie: .fairway,
            approachLie: .green,
            puttDistances: [10, 2] // first 10ft missed, follow-up 2ft made
        )
        let aggregates = TrendCarouselAggregates.build(
            eligible: [
                CompletedRound(
                    id: UUID(),
                    datePlayed: Date(),
                    par: 4,
                    totalScore: 5,
                    holesPlayed: .eighteen,
                    holeStats: [hole]
                ),
            ],
            allRounds: []
        )
        let tenFoot = aggregates.makePctByDistance[.feet7to10] ?? PuttMakeStat()
        let twoFoot = aggregates.makePctByDistance[.feet0to3] ?? PuttMakeStat()
        // First putt was 10ft, not made (it was followed by another putt).
        #expect(tenFoot.attempted == 1)
        #expect(tenFoot.made == 0)
        // Second putt was 2ft, made (it was the last entry).
        #expect(twoFoot.attempted == 1)
        #expect(twoFoot.made == 1)
    }

    // MARK: - Hole heat last 20

    @Test("Hole heat grid pins to last 20 newest-first, ignores filter")
    func heatGridLast20() {
        let rounds = (0..<25).map { dayOffset in
            roundWith(
                par: 72,
                daysAgo: dayOffset,
                holes: (0..<18).map { _ in hole(par: 4, strokes: 4, putts: 2) }
            )
        }
        // Only first 10 are "eligible" by some filter — the grid still
        // shows the full last 20 from the raw archive.
        let aggregates = TrendCarouselAggregates.build(
            eligible: Array(rounds.prefix(10)),
            allRounds: rounds
        )
        #expect(aggregates.holeHeatLast20.count == 20)
    }

    @Test("Hole heat row uses 18 cells; absent strokes leave nil")
    func heatGridCellsShape() {
        // Front-9 only.
        let holes = (0..<9).map { _ in hole(par: 4, strokes: 4, putts: 2) }
        let round = roundWith(par: 36, holes: holes, holesPlayed: .front9)
        let aggregates = TrendCarouselAggregates.build(
            eligible: [],
            allRounds: [round]
        )
        let row = aggregates.holeHeatLast20.first
        #expect(row?.cells.count == 18)
        // First 9 cells populated, back-9 nil.
        let frontCount = row?.cells.prefix(9).compactMap { $0 }.count ?? 0
        let backCount = row?.cells.suffix(9).compactMap { $0 }.count ?? 0
        #expect(frontCount == 9)
        #expect(backCount == 0)
    }

    // MARK: - Helpers

    private func hole(
        par: Int,
        strokes: Int,
        putts: Int,
        teeLie: Lie? = nil,
        approachLie: Lie? = nil
    ) -> HoleStat {
        HoleStat(
            par: par,
            strokes: strokes,
            putts: putts,
            teeShotLie: teeLie,
            approachLie: approachLie
        )
    }

    private func roundWith(
        par: Int,
        daysAgo: Int = 0,
        holes: [HoleStat],
        holesPlayed: HolesPlayed = .eighteen
    ) -> CompletedRound {
        let date = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return CompletedRound(
            id: UUID(),
            datePlayed: date,
            par: par,
            totalScore: holes.reduce(0) { $0 + $1.strokes },
            holesPlayed: holesPlayed,
            holeStats: holes,
            roundType: nil,
            roundFormat: .stroke
        )
    }
}
