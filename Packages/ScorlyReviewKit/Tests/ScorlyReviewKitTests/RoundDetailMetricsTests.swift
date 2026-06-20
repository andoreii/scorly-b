import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyReviewKit

struct RoundDetailMetricsTests {
    @Test("Single round metrics only count played holes")
    func derivesReviewStatistics() {
        let round = CompletedRound(
            id: UUID(),
            datePlayed: Date(),
            par: 12,
            totalScore: 12,
            holesPlayed: .eighteen,
            holeStats: [
                hole(par: 3, strokes: 3, putts: 2, tee: .green, puttDistances: [9, 2]),
                hole(par: 4, strokes: 4, putts: 2, tee: .fairway, approach: .green, puttDistances: [10, 2]),
                hole(par: 5, strokes: 5, putts: 1, tee: .roughLeft, approach: .bunkerRight, puttDistances: [4]),
            ]
        )

        let metrics = RoundDetailMetrics(round: round)

        #expect(metrics.playedHoleCount == 3)
        #expect(metrics.scoreToPar == 0)
        #expect(metrics.totalPutts == 5)
        #expect(metrics.averagePuttsPerHole == 5.0 / 3.0)
        #expect(metrics.puttingAverageProfile.map(\.holeNumber) == [1, 2, 3])
        #expect(metrics.puttingAverageProfile.map(\.averagePuttsPerHole) == [2, 2, 5.0 / 3.0])
        #expect(metrics.puttDistribution.onePutt == 1)
        #expect(metrics.puttDistribution.twoPutt == 2)
        #expect(metrics.puttDistribution.threePuttPlus == 0)
        #expect(metrics.fairwayRose.opportunities == 2)
        #expect(metrics.fairwayRose.hitRate == 0.5)
        #expect(metrics.greenRose.opportunities == 3)
        #expect(metrics.greenRose.hitRate == 2.0 / 3.0)
        #expect(metrics.puttMakeStats[.feet7to10]?.attempted == 2)
        #expect(metrics.puttMakeStats[.feet7to10]?.made == 0)
        #expect(metrics.puttMakeStats[.feet0to3]?.made == 2)
        #expect(metrics.outcomes[.par] == 3)
    }

    @Test("Filed scorecard forms front and back groups for eighteen holes")
    func scorecardGroups() {
        let holes = (0..<18).map { index in
            hole(par: index % 3 + 3, strokes: index % 3 + 3, putts: 2)
        }
        let round = CompletedRound(
            id: UUID(),
            datePlayed: Date(),
            par: holes.reduce(0) { $0 + $1.par },
            totalScore: holes.reduce(0) { $0 + $1.strokes },
            holesPlayed: .eighteen,
            holeStats: holes
        )

        let groups = RoundDetailMetrics(round: round).scorecardGroups

        #expect(groups.map(\.label) == ["FRONT NINE", "BACK NINE"])
        #expect(groups[0].holes.map(\.number) == Array(1...9))
        #expect(groups[1].holes.map(\.number) == Array(10...18))
    }

    @Test("Back-nine filed cards retain printed hole numbers")
    func backNineScorecardGroup() {
        let holes = (0..<9).map { _ in hole(par: 4, strokes: 4, putts: 2) }
        let round = CompletedRound(
            id: UUID(),
            datePlayed: Date(),
            par: 36,
            totalScore: 36,
            holesPlayed: .back9,
            holeStats: holes
        )

        let groups = RoundDetailMetrics(round: round).scorecardGroups

        #expect(groups.map(\.label) == ["HOLES"])
        #expect(groups[0].holes.map(\.number) == Array(10...18))
    }

    @Test("Direct (holeStats:holesPlayed:) init treats unplayed holes (strokes == 0) as excluded")
    func directInitFiltersUnplayed() {
        let played = HoleStat(par: 4, strokes: 4, putts: 2)
        let unplayed = HoleStat(par: 4, strokes: 0, putts: 0)
        let metrics = RoundDetailMetrics(
            holeStats: [played, played, unplayed],
            holesPlayed: .front9
        )

        #expect(metrics.playedHoleCount == 2)
        #expect(metrics.totalPutts == 4)
        #expect(metrics.averagePuttsPerHole == 2.0)
        #expect(metrics.puttingAverageProfile.map(\.holeNumber) == [1, 2])
        #expect(metrics.puttingAverageProfile.map(\.averagePuttsPerHole) == [2, 2])
    }

    @Test("Direct init renders a back-9 single group numbered 10–18")
    func directBackNineScorecard() {
        let stats = (0..<9).map { _ in HoleStat(par: 4, strokes: 4, putts: 2) }
        let metrics = RoundDetailMetrics(holeStats: stats, holesPlayed: .back9)

        #expect(metrics.scorecardGroups.count == 1)
        #expect(metrics.scorecardGroups[0].holes.map(\.number) == Array(10...18))
        #expect(metrics.puttingAverageProfile.map(\.holeNumber) == Array(10...18))
    }

    @Test("Score to par sums played holes only")
    func scoreToPar() {
        let metrics = RoundDetailMetrics(
            holeStats: [
                hole(par: 4, strokes: 6, putts: 2),
                hole(par: 3, strokes: 2, putts: 1),
                hole(par: 5, strokes: 0, putts: 0),
            ],
            holesPlayed: .front9
        )

        #expect(metrics.scoreToPar == 1)
    }

    @Test("Empty rounds expose empty putting analysis")
    func emptyRoundPuttingAnalysis() {
        let metrics = RoundDetailMetrics(holeStats: [], holesPlayed: .front9)

        #expect(metrics.scoreToPar == 0)
        #expect(metrics.puttingAverageProfile.isEmpty)
        #expect(metrics.puttDistribution.total == 0)
    }

    private func hole(
        par: Int,
        strokes: Int,
        putts: Int,
        tee: Lie? = nil,
        approach: Lie? = nil,
        puttDistances: [Int]? = nil
    ) -> HoleStat {
        HoleStat(
            par: par,
            strokes: strokes,
            putts: putts,
            teeShotLie: tee,
            approachLie: approach,
            puttDistances: puttDistances
        )
    }
}
