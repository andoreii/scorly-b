import Foundation
import Testing
@testable import ScorlyDomain

/// SG hand-calc parity: runs SGCalculator end-to-end on a 4-hole sample
/// round and checks every shot/hole/round total against values hand-traced
/// through SGBenchmarks.json.
struct SGHandCalcParityTests {
    // MARK: - The sample round

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
