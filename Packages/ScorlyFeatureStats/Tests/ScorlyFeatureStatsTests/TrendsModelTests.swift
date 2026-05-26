import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyFeatureStats

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
                score: 72 + (i % 5) // 0..+4 vs par
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

    @Test("Eligibility filter applies before the window picks the sample")
    func eligibilityBeforeWindow() {
        // Build 25 rounds: alternating eligible 18-hole Stroke and
        // ineligible 18-hole Scramble. The default filter keeps every
        // other one — so LAST 20 should sample the 12-ish eligible
        // rounds available (not 20 from the raw archive).
        let rounds = (0..<25).map { i in
            makeRound(
                daysAgo: i,
                par: 72,
                score: 72 + i,
                holesPlayed: .eighteen,
                format: i.isMultiple(of: 2) ? .stroke : .scramble
            )
        }
        let eligible = rounds.eligible(for: .default)
        let model = TrendsModel.build(rounds: eligible, window: .twenty)
        // 13 eligible rounds (i = 0, 2, …, 24).
        #expect(eligible.count == 13)
        #expect(model.sampleCount == 13)
        // The first eligible round (i=0) becomes the most-recent in the
        // sample. The sample's avgVsPar should match the mean of the
        // eligible vs-par values — not the raw-archive mean.
        let eligibleVsPar = eligible.map(\.scoreVsPar).reduce(0, +)
        let expectedAvg = Double(eligibleVsPar) / Double(eligible.count)
        #expect(model.avgVsPar == expectedAvg)
    }

    @Test("9-hole and scramble rounds are skipped by default sample")
    func defaultExcludes9HoleAndScramble() {
        let eligible18 = (0..<5).map { makeRound(daysAgo: $0, par: 72, score: 80) }
        let nineHole = makeRound(daysAgo: 100, par: 36, score: 40, holesPlayed: .front9)
        let scramble = makeRound(daysAgo: 101, par: 72, score: 65, holesPlayed: .eighteen, format: .scramble)
        let model = TrendsModel.build(
            rounds: (eligible18 + [nineHole, scramble]).eligible(for: .default),
            window: .twenty
        )
        // Only the five 18-hole stroke rounds survive.
        #expect(model.sampleCount == 5)
        // The scramble's 65 totalScore would dominate if it slipped through.
        #expect((model.bestVsPar ?? -99) == 8)
    }

    // MARK: - Helpers

    private func makeRound(
        daysAgo: Int,
        par: Int,
        score: Int,
        holesPlayed: HolesPlayed = .eighteen,
        format: RoundFormat? = .stroke
    ) -> CompletedRound {
        let date = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return CompletedRound(
            id: UUID(),
            datePlayed: date,
            par: par,
            totalScore: score,
            holesPlayed: holesPlayed,
            holeStats: [],
            roundType: nil,
            roundFormat: format
        )
    }
}
