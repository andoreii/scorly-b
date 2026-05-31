import Foundation
import Testing
@testable import ScorlyDomain

struct SGCalculatorTests {
    // MARK: - Lie → benchmark mapping

    @Test("Lie maps to the 5 Broadie benchmark categories")
    func lieMapping() {
        #expect(SGCalculator.sgBenchmark(for: .fairway) == .fairway)
        #expect(SGCalculator.sgBenchmark(for: .roughLeft) == .rough)
        #expect(SGCalculator.sgBenchmark(for: .roughRight) == .rough)
        #expect(SGCalculator.sgBenchmark(for: .bunkerLeft) == .sand)
        #expect(SGCalculator.sgBenchmark(for: .bunkerRight) == .sand)
        #expect(SGCalculator.sgBenchmark(for: .bunkerShort) == .sand)
        #expect(SGCalculator.sgBenchmark(for: .bunkerLong) == .sand)
        #expect(SGCalculator.sgBenchmark(for: .recoveryLeft) == .recovery)
        #expect(SGCalculator.sgBenchmark(for: .recoveryRight) == .recovery)
        #expect(SGCalculator.sgBenchmark(for: .recoveryShort) == .recovery)
        #expect(SGCalculator.sgBenchmark(for: .recoveryLong) == .recovery)
        #expect(SGCalculator.sgBenchmark(for: .green) == .green)
    }

    // MARK: - Per-shot SG math

    @Test("Per-shot SG = E(start) − E(end) − 1")
    func perShotFormula() {
        let table = SGBenchmarkTable.bundled
        let start = ShotPosition(lie: .fairway, distance: 100)
        let end = ShotEnd.position(ShotPosition(lie: .green, distance: 5))
        // E(fairway, 100) = 2.80; E(green, 5) = 1.23; SG = 2.80 − 1.23 − 1 = 0.57
        #expect(SGCalculator.shotSG(start: start, end: end, benchmarks: table) == dec("0.57"))
    }

    @Test("Holed shot: SG = E(start) − 1")
    func holedShotFormula() {
        let table = SGBenchmarkTable.bundled
        let start = ShotPosition(lie: .green, distance: 5)
        // E(green, 5) = 1.23; holed → SG = 1.23 − 1 = 0.23
        #expect(SGCalculator.shotSG(start: start, end: .holed, benchmarks: table) == dec("0.23"))
    }

    @Test("Unknown start returns nil")
    func unknownStartIsNil() {
        let table = SGBenchmarkTable.bundled
        #expect(
            SGCalculator.shotSG(start: nil, end: .holed, benchmarks: table) == nil
        )
    }

    @Test("Unknown end returns nil")
    func unknownEndIsNil() {
        let table = SGBenchmarkTable.bundled
        let start = ShotPosition(lie: .fairway, distance: 100)
        #expect(
            SGCalculator.shotSG(start: start, end: .unknown, benchmarks: table) == nil
        )
    }

    // MARK: - Aggregation

    @Test("Aggregate excludes nil shots; empty category sums to 0")
    func aggregateExcludesNils() {
        let shots: [SGShotResult] = [
            SGShotResult(category: .ott, strokesGained: dec("0.5")),
            SGShotResult(category: .ott, strokesGained: nil),
            SGShotResult(category: .app, strokesGained: dec("0.2")),
            SGShotResult(category: .putt, strokesGained: dec("-0.1")),
            // .arg has no entries → totals.arg should be 0.
        ]
        let totals = SGCalculator.aggregate(shots)
        #expect(totals.ott == dec("0.5"))
        #expect(totals.app == dec("0.2"))
        #expect(totals.arg == 0)
        #expect(totals.putt == dec("-0.1"))
        #expect(totals.total == dec("0.6"))
    }

    @Test("Aggregate of all-nil shots in a category yields 0")
    func aggregateAllNilCategory() {
        let shots: [SGShotResult] = [
            SGShotResult(category: .arg, strokesGained: nil),
            SGShotResult(category: .arg, strokesGained: nil),
        ]
        let totals = SGCalculator.aggregate(shots)
        #expect(totals.arg == 0)
        #expect(totals.total == 0)
    }

    // MARK: - Reconstruction: par 4 — clean GIR + 2 putts

    @Test("Par 4: tee → fairway → green → 2 putts produces OTT/APP/PUTT/PUTT")
    func par4CleanGIR() {
        let input = HoleSGInput(
            par: 4,
            yardage: 400,
            teeShotLie: .fairway,
            teeShotDistance: 250, // remaining = 150 yds
            approachLie: .green,
            approachDistance: 150,
            puttDistancesFeet: [20, 3], // first putt 20 ft, second 3 ft
            strokes: 4
        )
        let result = SGCalculator.computeHole(input)
        #expect(result.shots.map(\.category) == [.ott, .app, .putt, .putt])

        // OTT: E(tee, 400)=3.99 − E(fairway, 150)=2.945 − 1 = 0.045
        #expect(result.shots[0].strokesGained == dec("0.045"))
        // APP: E(fairway, 150)=2.945 − E(green, 20)=1.87 − 1 = 0.075
        #expect(result.shots[1].strokesGained == dec("0.075"))
        // PUTT 1: E(green, 20)=1.87 − E(green, 3)=1.04 − 1 = -0.17
        #expect(result.shots[2].strokesGained == dec("-0.17"))
        // PUTT 2: holed from 3 ft. E(green, 3)=1.04 − 1 = 0.04
        #expect(result.shots[3].strokesGained == dec("0.04"))

        // Total = 0.045 + 0.075 − 0.17 + 0.04 = -0.01
        #expect(result.totals.total == dec("-0.01"))
    }

    // MARK: - Reconstruction: par 3 — ace

    @Test("Par 3 ace: single APP shot with end .holed")
    func par3Ace() {
        let input = HoleSGInput(
            par: 3,
            yardage: 165,
            teeShotLie: .green,
            puttDistancesFeet: [],
            strokes: 1
        )
        let result = SGCalculator.computeHole(input)
        #expect(result.shots.count == 1)
        #expect(result.shots[0].category == .app)
        // Par-3 tee uses fairway baseline. E(fairway, 165) interpolated:
        // 160=2.98, 180=3.08 → 165 = 2.98 + (5/20)*0.10 = 3.005
        // SG = 3.005 − 0 − 1 = 2.005
        #expect(result.shots[0].strokesGained == dec("2.005"))
    }

    // MARK: - Reconstruction: par 3 — green in regulation, 2 putts

    @Test("Par 3 GIR + 2 putts: APP/PUTT/PUTT")
    func par3GIRThenTwoPutts() {
        let input = HoleSGInput(
            par: 3,
            yardage: 150,
            teeShotLie: .green,
            puttDistancesFeet: [25, 4],
            strokes: 3
        )
        let result = SGCalculator.computeHole(input)
        #expect(result.shots.map(\.category) == [.app, .putt, .putt])
        // APP: E(fairway, 150)=2.945 − E(green, 25)=1.94 − 1 = 0.005
        #expect(result.shots[0].strokesGained == dec("0.005"))
    }

    // MARK: - Reconstruction: par 5 — chip-in (ARG holed without putts)

    @Test("Par 5 chip-in (3 strokes, no putts): chip computed from default chip-start")
    func par5ChipInNoPutts() {
        let input = HoleSGInput(
            par: 5,
            yardage: 540,
            teeShotLie: .fairway,
            teeShotDistance: 280, // remaining = 260
            approachLie: .roughLeft, // missed green
            approachDistance: 260,
            puttDistancesFeet: [], // chip-in: no putts
            strokes: 3
        )
        let result = SGCalculator.computeHole(input)
        // Categories: OTT, APP, ARG (holed)
        #expect(result.shots.map(\.category) == [.ott, .app, .arg])
        // OTT: E(tee, 540)=4.65 − E(fairway, 260)=3.58 − 1 = 0.07
        #expect(result.shots[0].strokesGained == dec("0.07"))
        // APP: no landing distance recorded → defaults to (rough, 20yd).
        //   E(fairway, 260)=3.58 − E(rough, 20)=2.59 − 1 = -0.01
        #expect(result.shots[1].strokesGained == dec("-0.01"))
        // ARG (holed chip): E(rough, 20)=2.59 − 0 − 1 = 1.59
        #expect(result.shots[2].strokesGained == dec("1.59"))
        #expect(result.totals.arg == dec("1.59"))
        // Total telescopes to E(tee, 540) − strokes = 1.65
        #expect(result.totals.total == dec("1.65"))
    }

    @Test("Par 5 in 4 with no putts: intermediate ARG uses chained defaults")
    func par5FourStrokesNoPutts() {
        let input = HoleSGInput(
            par: 5,
            yardage: 540,
            teeShotLie: .fairway,
            teeShotDistance: 280,
            approachLie: .roughLeft,
            approachDistance: 260,
            puttDistancesFeet: [],
            strokes: 4
        )
        let result = SGCalculator.computeHole(input)
        // 2 ARG shots — intermediate uses the 10yd intermediate default,
        // last is holed. Every shot is bounded; no nils.
        #expect(result.shots.map(\.category) == [.ott, .app, .arg, .arg])
        // OTT = 0.07, APP = -0.01 (same chain entry as par5ChipInNoPutts)
        #expect(result.shots[0].strokesGained == dec("0.07"))
        #expect(result.shots[1].strokesGained == dec("-0.01"))
        // ARG[0]: E(rough, 20)=2.59 − E(rough, 10)=2.34 − 1 = -0.75
        #expect(result.shots[2].strokesGained == dec("-0.75"))
        // ARG[1]: E(rough, 10)=2.34 − 0 − 1 = 1.34
        #expect(result.shots[3].strokesGained == dec("1.34"))
        // ARG total = -0.75 + 1.34 = 0.59
        #expect(result.totals.arg == dec("0.59"))
        // Total telescopes to E(tee, 540) − 4 = 0.65
        #expect(result.totals.total == dec("0.65"))
    }

    // MARK: - Reconstruction: par 4 — missed green, chip + 2 putts (ARG with intermediate)

    @Test("Par 4 ARG: tee/approach/chip/putt/putt produces 1 ARG, 2 PUTT")
    func par4MissedGreenChipAndTwoPutts() {
        let input = HoleSGInput(
            par: 4,
            yardage: 380,
            teeShotLie: .fairway,
            teeShotDistance: 240, // remaining = 140
            approachLie: .bunkerLeft, // missed in greenside bunker
            approachDistance: 140,
            puttDistancesFeet: [10, 2],
            strokes: 5
        )
        let result = SGCalculator.computeHole(input)
        #expect(result.shots.map(\.category) == [.ott, .app, .arg, .putt, .putt])
        // OTT: E(tee, 380)=3.96 − E(fairway, 140)=2.91 − 1 = 0.05
        #expect(result.shots[0].strokesGained == dec("0.05"))
        // APP: no landing distance → bunker default = 12yd from pin.
        //   E(sand, 12) = 2.43 + 0.2 × (2.53 − 2.43) = 2.45
        //   APP = E(fairway, 140)=2.91 − 2.45 − 1 = -0.54
        #expect(result.shots[1].strokesGained == dec("-0.54"))
        // ARG (chip onto green): E(sand, 12)=2.45 − E(green, 10)=1.61 − 1 = -0.16
        #expect(result.shots[2].strokesGained == dec("-0.16"))
        // PUTT1: E(green, 10)=1.61 − E(green, 2 clamps to 1.04) − 1 = -0.43
        #expect(result.shots[3].strokesGained == dec("-0.43"))
        // PUTT2: E(green, 2 → 1.04) − 0 − 1 = 0.04
        #expect(result.shots[4].strokesGained == dec("0.04"))
        #expect(result.totals.arg == dec("-0.16"))
        // Total telescopes to E(tee, 380) − 5 = -1.04
        #expect(result.totals.total == dec("-1.04"))
    }

    // MARK: - Explicit user data overrides defaults

    @Test("Par 4 with explicit argShots: chip start uses user data, not default")
    func par4ExplicitARGShot() {
        let input = HoleSGInput(
            par: 4,
            yardage: 380,
            teeShotLie: .fairway,
            teeShotDistance: 240,
            approachLie: .roughLeft,
            approachDistance: 140,
            puttDistancesFeet: [6, 2],
            strokes: 5,
            approachLandingDistance: 25, // 25yd from pin in the rough
            argShots: [ARGShot(lie: .roughLeft, distanceToPinYards: 25)]
        )
        let result = SGCalculator.computeHole(input)
        // APP end at rough, 25yd: E(rough, 25) = 2.59 + 0.5 × (2.70 − 2.59) = 2.645
        //   APP = E(fairway, 140)=2.91 − 2.645 − 1 = -0.735
        #expect(result.shots[1].strokesGained == dec("-0.735"))
        // ARG uses the user-recorded distance (25yd rough).
        //   ARG = E(rough, 25)=2.645 − E(green, 6)=1.34 − 1 = 0.305
        #expect(result.shots[2].strokesGained == dec("0.305"))
        // Total still telescopes to E(tee, 380) − 5 = -1.04
        #expect(result.totals.total == dec("-1.04"))
    }

    @Test("Par 5 with layup: layup shot inserted between tee and approach")
    func par5WithLayup() {
        let input = HoleSGInput(
            par: 5,
            yardage: 540,
            teeShotLie: .fairway,
            teeShotDistance: 260, // tee end = (fairway, 280)
            approachLie: .green,
            approachDistance: 100, // entered for the approach
            puttDistancesFeet: [15, 3],
            strokes: 5,
            layupLie: .fairway,
            layupDistance: 100
        )
        let result = SGCalculator.computeHole(input)
        // Categories: OTT, APP (layup), APP (approach), PUTT, PUTT
        #expect(result.shots.map(\.category) == [.ott, .app, .app, .putt, .putt])
        // OTT: E(tee, 540)=4.65 − E(fairway, 280)=3.69 − 1 = -0.04
        #expect(result.shots[0].strokesGained == dec("-0.04"))
        // Layup: E(fairway, 280)=3.69 − E(fairway, 100)=2.80 − 1 = -0.11
        #expect(result.shots[1].strokesGained == dec("-0.11"))
        // Approach (onto green at 15ft): E(fairway, 100)=2.80 − E(green, 15)=1.78 − 1 = 0.02
        #expect(result.shots[2].strokesGained == dec("0.02"))
        // Total = E(tee, 540) − 5 = -0.35
        #expect(result.totals.total == dec("-0.35"))
    }

    @Test("Par 5 with layup and holed approach ends approach shot as holed")
    func par5LayupHoledApproach() {
        let input = HoleSGInput(
            par: 5,
            yardage: 540,
            teeShotLie: .fairway,
            teeShotDistance: 280,
            approachLie: .green,
            approachDistance: 100,
            puttDistancesFeet: [],
            strokes: 3,
            layupLie: .fairway,
            layupDistance: 100
        )
        let reconstructed = SGCalculator.reconstruct(input)

        #expect(reconstructed.map(\.category) == [.ott, .app, .app])
        #expect(reconstructed[2].end == .holed)
    }

    // MARK: - Reconstruction: missing data → nil per shot

    @Test("Missing tee shot lie → OTT shot has nil SG")
    func missingTeeShotLie() {
        let input = HoleSGInput(
            par: 4,
            yardage: 400,
            teeShotLie: nil, // user didn't record
            teeShotDistance: nil,
            approachLie: .green,
            approachDistance: nil,
            puttDistancesFeet: [15, 2],
            strokes: 4
        )
        let result = SGCalculator.computeHole(input)
        // OTT start is known (.tee, 400), end is unknown → SG nil.
        #expect(result.shots[0].strokesGained == nil)
        // APP start is unknown (no tee shot lie) → SG nil.
        #expect(result.shots[1].strokesGained == nil)
        // Putts still compute.
        #expect(result.shots[2].strokesGained != nil)
        #expect(result.shots[3].strokesGained != nil)
    }

    @Test("teeShotDistance ≥ yardage → OTT end unknown, SG nil")
    func teeShotDistanceExceedsYardage() {
        let input = HoleSGInput(
            par: 4,
            yardage: 350,
            teeShotLie: .fairway,
            teeShotDistance: 350, // remaining = 0 → unknown
            approachLie: .green,
            approachDistance: 0,
            puttDistancesFeet: [10, 2],
            strokes: 4
        )
        let result = SGCalculator.computeHole(input)
        #expect(result.shots[0].strokesGained == nil)
    }

    @Test("Zero strokes → no shots reconstructed")
    func zeroStrokesNoShots() {
        let input = HoleSGInput(par: 4, yardage: 400, strokes: 0)
        let result = SGCalculator.computeHole(input)
        #expect(result.shots.isEmpty)
        #expect(result.totals.total == 0)
    }

    // MARK: - Round aggregation

    @Test("Round totals are the sum of every hole's per-category totals")
    func roundAggregatesAcrossHoles() {
        let hole1 = HoleSGInput(
            par: 4,
            yardage: 400,
            teeShotLie: .fairway,
            teeShotDistance: 250,
            approachLie: .green,
            approachDistance: 150,
            puttDistancesFeet: [20, 3],
            strokes: 4
        )
        let hole2 = HoleSGInput(
            par: 3,
            yardage: 150,
            teeShotLie: .green,
            puttDistancesFeet: [25, 4],
            strokes: 3
        )
        let round = SGCalculator.compute(holes: [hole1, hole2])
        #expect(round.holes.count == 2)
        // Round totals.ott = hole1.ott + hole2.ott (hole2 has no OTT shots = 0)
        #expect(round.totals.ott == round.holes[0].totals.ott)
        // Round totals.app = hole1.app + hole2.app
        #expect(round.totals.app == round.holes[0].totals.app + round.holes[1].totals.app)
        // Round total = sum of all 4 categories
        #expect(
            round.totals.total ==
                round.totals.ott + round.totals.app + round.totals.arg + round.totals.putt
        )
    }

    @Test("Empty hole list → all-zero totals")
    func emptyHoleList() {
        let result = SGCalculator.compute(holes: [])
        #expect(result.holes.isEmpty)
        #expect(result.totals.total == 0)
        #expect(result.totals.ott == 0)
        #expect(result.totals.app == 0)
        #expect(result.totals.arg == 0)
        #expect(result.totals.putt == 0)
    }

    // MARK: - Helper

    private func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: nil) ?? .nan
    }
}
