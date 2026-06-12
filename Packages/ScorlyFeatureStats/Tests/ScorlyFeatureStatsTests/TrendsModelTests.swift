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
        // Alternating eligible/ineligible rounds; window should sample
        // from the filtered set, not the raw archive.
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
        #expect(eligible.count == 13)
        #expect(model.sampleCount == 13)
        // Sample average should match the eligible set's mean, not the raw archive's.
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

    // MARK: - Radar

    @Test("Percentile maps to 0 at the lower anchor and 100 at the upper")
    func radarPercentileAnchors() {
        #expect(RadarAxis.percentile(value: -1.5, lower: -1.5, upper: 1.5) == 0)
        #expect(RadarAxis.percentile(value: 1.5, lower: -1.5, upper: 1.5) == 100)
        #expect(RadarAxis.percentile(value: 0, lower: -1.5, upper: 1.5) == 50)
    }

    @Test("Percentile clamps outside the band")
    func radarPercentileClamps() {
        #expect(RadarAxis.percentile(value: -10, lower: -1.5, upper: 1.5) == 0)
        #expect(RadarAxis.percentile(value: 10, lower: -1.5, upper: 1.5) == 100)
    }

    @Test("Inverted band rewards lower values")
    func radarPercentileInverted() {
        // Trouble Avoidance: lower per-hole trouble is better.
        // band = [0.6, 0.0]; value 0.0 → 100, 0.6 → 0, 0.3 → 50.
        #expect(RadarAxis.percentile(value: 0.0, lower: 0.6, upper: 0.0) == 100)
        #expect(RadarAxis.percentile(value: 0.6, lower: 0.6, upper: 0.0) == 0)
        #expect(RadarAxis.percentile(value: 0.3, lower: 0.6, upper: 0.0) == 50)
    }

    @Test("Eight radar axes always present, even when sample is empty")
    func radarAxesAlwaysEight() {
        let empty = TrendsModel.build(rounds: [], window: .twenty)
        #expect(empty.radarAxes.count == 8)
        // Every key is present.
        let keys = Set(empty.radarAxes.map(\.key))
        #expect(keys == Set(RadarAxisKey.allCases))
        // Empty sample → every axis falls back to 0.
        #expect(empty.radarAxes.allSatisfy { $0.windowValue == 0 && $0.seasonValue == 0 })
    }

    @Test("Putting axis maps recorded putts per 18 into a calibrated band")
    func radarPuttingFromRecordedPutts() {
        // 33 putts / 18 sits halfway between the 39 and 27 anchors.
        let rounds = [makePuttRound(daysAgo: 0, totalPutts: 33)]
        let model = TrendsModel.build(rounds: rounds, window: .ten)
        let putting = model.radarAxes.first { $0.key == .putting }
        #expect(putting?.windowValue == 50)
        #expect(putting?.seasonValue == 50)
    }

    @Test("Season score spans the whole eligible set, window only the prefix")
    func radarSeasonVsWindow() {
        // 10 newest at top-of-band, 5 older at bottom-of-band putts.
        var rounds: [CompletedRound] = []
        for offset in 0..<10 {
            rounds.append(makePuttRound(daysAgo: offset, totalPutts: 27))
        }
        for offset in 0..<5 {
            rounds.append(makePuttRound(daysAgo: 100 + offset, totalPutts: 39))
        }
        let model = TrendsModel.build(rounds: rounds, window: .ten)
        let putt = model.radarAxes.first { $0.key == .putting }
        #expect(putt?.windowValue == 100)
        #expect(putt?.seasonValue == 67)
        #expect((putt?.delta ?? 0) == 33)
    }

    @Test("Radar profile uses recorded scorecard stats instead of partial SG totals")
    func radarUsesCompleteScorecardMetrics() {
        let round = CompletedRound(
            id: UUID(),
            datePlayed: Date(),
            par: 15,
            totalScore: 16,
            holesPlayed: .eighteen,
            holeStats: [
                HoleStat(
                    par: 4, strokes: 4, putts: 2,
                    teeShotLie: .fairway, approachLie: .green,
                    teeShotDistance: 240
                ),
                HoleStat(
                    par: 4, strokes: 5, putts: 2,
                    teeShotLie: .roughLeft, approachLie: .recoveryShort,
                    teeShotDistance: 230
                ),
                HoleStat(
                    par: 3, strokes: 3, putts: 2,
                    teeShotLie: .green
                ),
                HoleStat(
                    par: 4, strokes: 4, putts: 1,
                    teeShotLie: .roughRight, approachLie: .recoveryShort,
                    teeShotDistance: 235
                ),
            ],
            sgTotals: SGTotals(ott: 0, app: 100, arg: 100, putt: -100, total: 100),
            roundFormat: .stroke
        )

        let axes = Dictionary(uniqueKeysWithValues: RadarAxis.makeAll(window: [round], season: [round])
            .map { ($0.key, $0.windowValue) })
        #expect(axes[.putting] == 63)
        #expect(axes[.drivingDistance] == 45)
        #expect(axes[.approach] == 70)
        #expect(axes[.shortGame] == 91)
    }

    @Test("Trouble Avoidance is not eligible for strongest area")
    func radarStrongestExcludesTroubleAvoidance() {
        let axes = [
            RadarAxis(key: .troubleAvoidance, windowValue: 100, seasonValue: 100),
            RadarAxis(key: .approach, windowValue: 80, seasonValue: 80),
        ]

        #expect(RadarAxis.strongest(in: axes)?.key == .approach)
    }

    @Test("Trouble Avoidance alone does not become strongest area")
    func radarStrongestHasNoTroubleOnlyFallback() {
        let axes = [
            RadarAxis(key: .troubleAvoidance, windowValue: 100, seasonValue: 100),
        ]

        #expect(RadarAxis.strongest(in: axes) == nil)
    }

    @Test("Radar delta direction exposes arrows for changed values only")
    func radarDeltaDirectionArrow() {
        let improved = RadarAxis(key: .approach, windowValue: 56, seasonValue: 50)
        let declined = RadarAxis(key: .putting, windowValue: 28, seasonValue: 32)
        let unchanged = RadarAxis(key: .teeAccuracy, windowValue: 23, seasonValue: 23)

        #expect(improved.trendDirection == .up)
        #expect(improved.trendDirection.arrow == "↑")
        #expect(declined.trendDirection == .down)
        #expect(declined.trendDirection.arrow == "↓")
        #expect(unchanged.trendDirection == .unchanged)
        #expect(unchanged.trendDirection.arrow == nil)
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

    private func makePuttRound(daysAgo: Int, totalPutts: Int) -> CompletedRound {
        let date = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let basePutts = totalPutts / 18
        let extraPutts = totalPutts % 18
        let stats = (0..<18).map { index in
            let putts = basePutts + (index < extraPutts ? 1 : 0)
            return HoleStat(
                par: 4,
                strokes: putts + 2,
                putts: putts,
                teeShotLie: .fairway,
                approachLie: .green
            )
        }
        return CompletedRound(
            id: UUID(),
            datePlayed: date,
            par: 72,
            totalScore: stats.reduce(0) { $0 + $1.strokes },
            holesPlayed: .eighteen,
            holeStats: stats,
            roundType: nil,
            roundFormat: .stroke
        )
    }
}
