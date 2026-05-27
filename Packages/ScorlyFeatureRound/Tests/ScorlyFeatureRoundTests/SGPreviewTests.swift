import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyFeatureRound

struct SGPreviewTests {
    @Test("Returns nil when any hole is missing recorded putt distances")
    func nilWhenAHoleLacksPuttDistances() {
        let holes = (1...3).map { hole(number: $0, par: 4) }
        let stats: [HoleStat] = [
            stat(par: 4, strokes: 4, puttDistances: [10, 2]),
            stat(par: 4, strokes: 4, puttDistances: nil),
            stat(par: 4, strokes: 4, puttDistances: []),
        ]
        let yardages = Dictionary(uniqueKeysWithValues: (1...3).map { ($0, 400) })

        let result = SGPreview.compute(
            holes: holes,
            stats: stats,
            yardageByHoleNumber: yardages
        )
        #expect(result.totals == nil)
        #expect(result.holes == nil)
    }

    @Test("Returns nil when the tee has no yardage for a played hole")
    func nilWhenAHoleLacksYardage() {
        let holes = (1...3).map { hole(number: $0, par: 4) }
        let stats: [HoleStat] = holes.map { _ in
            stat(par: 4, strokes: 4, puttDistances: [10, 2])
        }
        let yardages = [1: 400, 3: 380] // missing hole 2

        let result = SGPreview.compute(
            holes: holes,
            stats: stats,
            yardageByHoleNumber: yardages
        )
        #expect(result.totals == nil)
        #expect(result.holes == nil)
    }

    @Test("Returns non-nil totals when every hole is fully populated")
    func nonNilWhenFullyPopulated() {
        let holes = (1...3).map { hole(number: $0, par: 4) }
        let stats: [HoleStat] = holes.map { _ in
            stat(par: 4, strokes: 4, puttDistances: [12, 3])
        }
        let yardages = Dictionary(uniqueKeysWithValues: (1...3).map { ($0, 400) })

        let result = SGPreview.compute(
            holes: holes,
            stats: stats,
            yardageByHoleNumber: yardages
        )
        #expect(result.totals != nil)
        #expect(result.holes?.count == 3)
    }

    @Test("Empty hole list returns nil (nothing to compute)")
    func emptyReturnsNil() {
        let result = SGPreview.compute(
            holes: [],
            stats: [],
            yardageByHoleNumber: [:]
        )
        #expect(result.totals == nil)
        #expect(result.holes == nil)
    }

    private func hole(number: Int, par: Int) -> Hole {
        Hole(id: UUID(), externalId: UUID(), number: number, par: par)
    }

    private func stat(
        par: Int,
        strokes: Int,
        puttDistances: [Int]?
    ) -> HoleStat {
        HoleStat(
            par: par,
            strokes: strokes,
            putts: puttDistances?.count ?? 0,
            puttDistances: puttDistances
        )
    }
}
