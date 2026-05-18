import Foundation
import Testing
@testable import ScorlyDomain

/// SG hand-calc parity. Exercises the full SGCalculator end-to-end against
/// a fully-instrumented 4-hole sample round whose per-shot values are
/// hand-traced through `SGBenchmarks.json` in the comments below. If any
/// of these expectations break, the failure diff points directly to which
/// reconstruction step diverged from the hand calc.
///
/// Plan invariant covered: "SG totals match a hand-calc on one fully-
/// instrumented sample round" (Phase B7).
struct SGHandCalcParityTests {
    // MARK: - The sample round

    //
    // Hole 1 — Par 4, 380y
    //   Drive: fairway, 280y travelled → 100y remaining
    //   Approach: green, 20 ft from hole
    //   2 putts: 20 ft → 5 ft → holed
    //   Per-shot SG (from Broadie tables):
    //     OTT  E(tee,380)=3.96  − E(fairway,100)=2.80 − 1 =  0.16
    //     APP  E(fairway,100)=2.80 − E(green,20)=1.87  − 1 = -0.07
    //     PUTT E(green,20)=1.87  − E(green,5)=1.23     − 1 = -0.36
    //     PUTT E(green,5)=1.23   − 0                   − 1 =  0.23
    //   Hole totals: OTT=0.16, APP=-0.07, ARG=0, PUTT=-0.13, Total=-0.04
    //
    // Hole 2 — Par 3, 160y
    //   Tee shot: green, 10 ft from hole; 1 putt
    //   Per-shot SG:
    //     APP  E(fairway,160)=2.98 − E(green,10)=1.61 − 1 = 0.37  (par-3 baseline = fairway)
    //     PUTT E(green,10)=1.61    − 0                − 1 = 0.61
    //   Hole totals: APP=0.37, PUTT=0.61, Total=0.98
    //
    // Hole 3 — Par 5, 500y (eagle attempt — reached in 2)
    //   Drive: fairway, 280y travelled → 220y remaining
    //   Approach: green, 30 ft from hole
    //   2 putts: 30 ft → 8 ft → holed
    //   Per-shot SG:
    //     OTT  E(tee,500)=4.41    − E(fairway,220)=3.32 − 1 =  0.09
    //     APP  E(fairway,220)=3.32 − E(green,30)=1.98    − 1 =  0.34
    //     PUTT E(green,30)=1.98   − E(green,8)=1.50     − 1 = -0.52
    //     PUTT E(green,8)=1.50    − 0                   − 1 =  0.50
    //   Hole totals: OTT=0.09, APP=0.34, PUTT=-0.02, Total=0.41
    //
    // Hole 4 — Par 4, 360y (recovery from bunker tee shot)
    //   Drive: bunker left, 200y travelled → 160y remaining
    //   Approach (from sand): green, 25 ft from hole
    //   2 putts: 25 ft → 6 ft → holed
    //   Per-shot SG:
    //     OTT  E(tee,360)=3.92   − E(sand,160)=3.31 − 1 = -0.39
    //     APP  E(sand,160)=3.31  − E(green,25)=1.94 − 1 =  0.37
    //     PUTT E(green,25)=1.94  − E(green,6)=1.34  − 1 = -0.40
    //     PUTT E(green,6)=1.34   − 0                − 1 =  0.34
    //   Hole totals: OTT=-0.39, APP=0.37, PUTT=-0.06, Total=-0.08
    //
    // Round totals (sum across all 4 holes):
    //   OTT   =  0.16 + 0    + 0.09 + (-0.39) = -0.14
    //   APP   = -0.07 + 0.37 + 0.34 + 0.37    =  1.01
    //   ARG   = 0
    //   PUTT  = -0.13 + 0.61 + (-0.02) + (-0.06) = 0.40
    //   Total = -0.14 + 1.01 + 0     + 0.40   =  1.27

    private let holes: [HoleSGInput] = [
        HoleSGInput(
            par: 4,
            yardage: 380,
            teeShotLie: .fairway,
            teeShotDistance: 280,
            approachLie: .green,
            approachDistance: 100,
            puttDistancesFeet: [20, 5],
            strokes: 4
        ),
        HoleSGInput(
            par: 3,
            yardage: 160,
            teeShotLie: .green,
            puttDistancesFeet: [10],
            strokes: 2
        ),
        HoleSGInput(
            par: 5,
            yardage: 500,
            teeShotLie: .fairway,
            teeShotDistance: 280,
            approachLie: .green,
            approachDistance: 220,
            puttDistancesFeet: [30, 8],
            strokes: 4
        ),
        HoleSGInput(
            par: 4,
            yardage: 360,
            teeShotLie: .bunkerLeft,
            teeShotDistance: 200,
            approachLie: .green,
            approachDistance: 160,
            puttDistancesFeet: [25, 6],
            strokes: 4
        ),
    ]

    // MARK: - Per-hole expectations

    @Test("Hole 1 — par 4 GIR + 2-putt matches hand calc to the cent")
    func hole1Matches() {
        let result = SGCalculator.computeHole(holes[0])
        #expect(result.shots.count == 4)
        #expect(result.shots[0].category == .ott)
        #expect(result.shots[0].strokesGained == dec("0.16"))
        #expect(result.shots[1].category == .app)
        #expect(result.shots[1].strokesGained == dec("-0.07"))
        #expect(result.shots[2].category == .putt)
        #expect(result.shots[2].strokesGained == dec("-0.36"))
        #expect(result.shots[3].category == .putt)
        #expect(result.shots[3].strokesGained == dec("0.23"))

        #expect(result.totals.ott == dec("0.16"))
        #expect(result.totals.app == dec("-0.07"))
        #expect(result.totals.arg == 0)
        #expect(result.totals.putt == dec("-0.13"))
        #expect(result.totals.total == dec("-0.04"))
    }

    @Test("Hole 2 — par 3 GIR + 1 putt categorises tee shot as APP")
    func hole2Matches() {
        let result = SGCalculator.computeHole(holes[1])
        #expect(result.shots.count == 2)
        #expect(result.shots[0].category == .app)
        #expect(result.shots[0].strokesGained == dec("0.37"))
        #expect(result.shots[1].category == .putt)
        #expect(result.shots[1].strokesGained == dec("0.61"))
        #expect(result.totals.app == dec("0.37"))
        #expect(result.totals.putt == dec("0.61"))
        #expect(result.totals.total == dec("0.98"))
    }

    @Test("Hole 3 — par 5 reached in 2, both fairway shots SG-positive")
    func hole3Matches() {
        let result = SGCalculator.computeHole(holes[2])
        #expect(result.shots.count == 4)
        #expect(result.shots[0].strokesGained == dec("0.09"))
        #expect(result.shots[1].strokesGained == dec("0.34"))
        #expect(result.shots[2].strokesGained == dec("-0.52"))
        #expect(result.shots[3].strokesGained == dec("0.50"))
        #expect(result.totals.ott == dec("0.09"))
        #expect(result.totals.app == dec("0.34"))
        #expect(result.totals.putt == dec("-0.02"))
        #expect(result.totals.total == dec("0.41"))
    }

    @Test("Hole 4 — bunker tee shot maps to sand benchmark, scrambling save")
    func hole4Matches() {
        let result = SGCalculator.computeHole(holes[3])
        #expect(result.shots[0].strokesGained == dec("-0.39"))
        #expect(result.shots[1].strokesGained == dec("0.37"))
        #expect(result.shots[2].strokesGained == dec("-0.40"))
        #expect(result.shots[3].strokesGained == dec("0.34"))
        #expect(result.totals.ott == dec("-0.39"))
        #expect(result.totals.app == dec("0.37"))
        #expect(result.totals.putt == dec("-0.06"))
        #expect(result.totals.total == dec("-0.08"))
    }

    // MARK: - Round totals

    @Test("Round-level SG totals sum to the hand-calculated values exactly")
    func roundTotalsMatch() {
        let round = SGCalculator.compute(holes: holes)
        #expect(round.totals.ott == dec("-0.14"))
        #expect(round.totals.app == dec("1.01"))
        #expect(round.totals.arg == 0)
        #expect(round.totals.putt == dec("0.40"))
        #expect(round.totals.total == dec("1.27"))
    }

    // MARK: - Helper

    private func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: nil) ?? .nan
    }
}
