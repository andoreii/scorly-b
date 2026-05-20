import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyFeatureRound

@MainActor
@Suite("RoundPlayState")
struct RoundPlayStateTests {
    @Test("Slices the right holes for F9 / B9 / 18")
    func holeSlicing() {
        let course = Self.makeCourse()
        let f9 = RoundPlayState(course: course, teeId: nil, holesPlayed: .front9)
        let b9 = RoundPlayState(course: course, teeId: nil, holesPlayed: .back9)
        let full = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        #expect(f9.holes.count == 9)
        #expect(f9.holes.map(\.number) == Array(1...9))
        #expect(b9.holes.count == 9)
        #expect(b9.holes.map(\.number) == Array(10...18))
        #expect(full.holes.count == 18)
    }

    @Test("Totals only count holes with logged strokes")
    func runningTotals() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        // Log holes 1 and 2 only.
        state.entries[0].strokes = 4
        state.entries[1].strokes = 6
        #expect(state.filledCount == 2)
        #expect(state.totalStrokes == 10)
        // Pars of holes 1+2 are 4+5=9 in the fixture.
        #expect(state.playedPar == 9)
        #expect(state.vsPar == 1)
    }

    @Test("derivedStat defaults strokes to par before the stepper is touched")
    func derivedStatGate() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        // Par-4 hole 1 in the fixture — with no input, strokes default to par.
        #expect(state.derivedStat(for: 0).strokes == 4)
        state.entries[0].strokes = 5
        #expect(state.derivedStat(for: 0).strokes == 5)
    }

    @Test("OB lie pushes the count, not the Lie field")
    func lieDecodingOB() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        state.entries[0].strokes = 6
        state.entries[0].teeShot = "OB Right"
        let stat = state.derivedStat(for: 0)
        #expect(stat.teeShotLie == nil)
        #expect(stat.outOfBoundsCount == 1)
    }

    @Test("Water Hazard pushes the hazard count")
    func lieDecodingHazard() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        state.entries[0].strokes = 6
        state.entries[0].approach = "Water Hazard"
        let stat = state.derivedStat(for: 0)
        #expect(stat.hazardCount == 1)
    }

    @Test("Fairway tee + green approach scores a GIR with two putts on a par-4")
    func girHappyPath() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        state.entries[0].strokes = 4
        state.entries[0].putts = 2
        state.entries[0].teeShot = "Fairway"
        state.entries[0].approach = "Green"
        let stat = state.derivedStat(for: 0)
        #expect(stat.greenInRegulation == true)
        #expect(stat.fairwayInRegulation == true)
    }

    @Test("Tee yardage resolves through the selected tee")
    func teeYardage() {
        let course = Self.makeCourse()
        let firstTee = course.tees[0]
        let state = RoundPlayState(course: course, teeId: firstTee.id, holesPlayed: .eighteen)
        #expect(state.teeYardageForCurrentHole == firstTee.teeHoles.first?.yardage)
    }

    // MARK: - Fixture

    private static func makeCourse() -> Course {
        let pars = [4, 5, 3, 4, 4, 5, 3, 4, 4, 4, 4, 3, 4, 5, 4, 4, 3, 5]
        let holes = pars.enumerated().map { offset, par in
            Hole(id: UUID(), externalId: UUID(), number: offset + 1, par: par, handicapIndex: offset + 1)
        }
        let teeHoles = (1...18).map { number in
            TeeHole(id: UUID(), externalId: UUID(), holeNumber: number, yardage: 350)
        }
        let tee = Tee(
            id: UUID(),
            externalId: UUID(),
            name: "White",
            courseRating: 71.2,
            slopeRating: 128,
            totalYardage: 6300,
            teeHoles: teeHoles
        )
        return Course(
            id: UUID(),
            externalId: UUID(),
            userId: UUID(),
            name: "Fixture GC",
            location: "Nowhere",
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            tees: [tee],
            holes: holes
        )
    }
}
