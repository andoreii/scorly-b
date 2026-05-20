import Foundation
@testable import ScorlyFeatureStats
import ScorlyDomain
import Testing

@Suite("TrendsModel")
struct TrendsModelTests {
    @Test("Empty rounds → empty model with zeroed figures")
    func emptyRoundsYieldEmptyModel() {
        let model = TrendsModel.build(rounds: [], window: .twenty)
        #expect(model.sampleCount == 0)
        #expect(model.avgVsPar == nil)
        #expect(model.bestVsPar == nil)
        #expect(model.timeline.isEmpty)
        #expect(model.distribution.isEmpty)
        #expect(model.sg == nil)
    }

    @Test("Sample respects window size and uses newest rounds")
    func windowPicksNewestRounds() {
        let rounds = (0..<25).map { i in
            makeRound(
                daysAgo: i,
                par: 72,
                score: 72 + (i % 5)  // 0..+4 vs par
            )
        }
        let m10 = TrendsModel.build(rounds: rounds, window: .ten)
        let m20 = TrendsModel.build(rounds: rounds, window: .twenty)
        #expect(m10.sampleCount == 10)
        #expect(m20.sampleCount == 20)
        // Newest round is daysAgo=0 → score 72 → vsPar 0.
        // Best should be 0 (or whatever is smallest in the prefix(10)).
        #expect(m10.bestVsPar != nil)
        #expect((m10.bestVsPar ?? 99) <= (m20.bestVsPar ?? 99))
    }

    @Test("Score buckets split correctly")
    func bucketing() {
        #expect(ScoreBucket.bucket(forVsPar: -3) == .eagleOrBetter)
        #expect(ScoreBucket.bucket(forVsPar: -2) == .eagleOrBetter)
        #expect(ScoreBucket.bucket(forVsPar: -1) == .birdie)
        #expect(ScoreBucket.bucket(forVsPar: 0) == .par)
        #expect(ScoreBucket.bucket(forVsPar: 1) == .bogey)
        #expect(ScoreBucket.bucket(forVsPar: 2) == .doublePlus)
        #expect(ScoreBucket.bucket(forVsPar: 5) == .doublePlus)
    }

    @Test("Delta vs prior window is exposed when there are 2N+ rounds")
    func priorWindowDelta() {
        // 20 newest rounds avg +3, 20 prior avg +5.
        let newer = (0..<20).map { makeRound(daysAgo: $0, par: 72, score: 75) }
        let older = (0..<20).map { makeRound(daysAgo: 100 + $0, par: 72, score: 77) }
        let model = TrendsModel.build(rounds: newer + older, window: .twenty)
        #expect(model.avgVsPar == 3.0)
        #expect(model.avgVsParPrev == 5.0)
    }

    // MARK: - Helpers

    private func makeRound(daysAgo: Int, par: Int, score: Int) -> CompletedRound {
        let date = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return CompletedRound(
            id: UUID(),
            datePlayed: date,
            par: par,
            totalScore: score,
            holesPlayed: .eighteen,
            holeStats: []
        )
    }
}
