import Foundation
import ScorlyDesignSystem
import ScorlyDomain
import Testing
@testable import ScorlyFeatureRound

@MainActor
struct RoundPlayInputDefaultsTests {
    @Test("Explicit missed actions reveal unlimited putts without radar input")
    func explicitMissesRevealUnlimitedPutts() {
        let state = makeState()
        state.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        state.applyPick(pick("Green", good: true), to: .approach, at: 0)

        for (shotIndex, distance) in [24, 8, 3, 1].enumerated() {
            state.recordMissedPutt(distance: distance, for: .putt(shotIndex), at: 0)

            let nodes = state.threadNodes(at: 0)
            #expect(nodes.last?.slot == .putt(shotIndex + 1))
            #expect(nodes.last?.logged == false)
        }

        state.recordHoledPutt(distance: 1, for: .putt(4), at: 0)

        #expect(state.entries[0].puttDistances == [24, 8, 3, 1, 1])
        #expect(state.entries[0].putts == 5)
        #expect(state.isHoleComplete(at: 0))
        #expect(state.derivedStat(for: 0).strokes == 7)
        #expect(state.derivedStat(for: 0).threePutt)
    }

    @Test("Shot defaults are zero except a par-3 tee shot uses hole yardage")
    func shotDistanceDefaults() {
        let state = makeState()

        #expect(state.resolvedSlotDistance(.tee, at: 0) == 0)
        #expect(state.resolvedSlotDistance(.second, at: 1) == 0)
        #expect(state.resolvedSlotDistance(.approach, at: 0) == 0)
        #expect(state.resolvedSlotDistance(.chip(0), at: 0) == 0)
        #expect(state.resolvedSlotDistance(.putt(0), at: 0) == 0)
        #expect(state.resolvedSlotDistance(.teeToGreen, at: 2) == 350)

        state.setSlotDistance(137, to: .approach, at: 0)
        #expect(state.resolvedSlotDistance(.approach, at: 0) == 137)

        let recorded = makeState()
        recorded.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        recorded.applyPick(pick("Green", good: true), to: .teeToGreen, at: 2)
        #expect(recorded.slotDistance(.tee, at: 0) == 0)
        #expect(recorded.slotDistance(.teeToGreen, at: 2) == 350)
    }

    @Test("Club selection atomically replaces distance with the fixed default")
    func clubSelectionAppliesDistanceDefault() {
        let state = makeState()
        let expected = [
            "Driver": 250, "3-Wood": 225, "5-Wood": 210, "Hybrid": 200,
            "3i": 195, "4i": 185, "5i": 175, "6i": 165,
            "7i": 150, "8i": 140, "9i": 130, "PW": 120,
            "50": 100, "54": 85, "58": 70, "Putter": 0,
        ]

        for club in brutalistClubs {
            state.setSlotDistance(999, to: .tee, at: 0)
            state.selectClub(club, for: .tee, at: 0)
            #expect(state.slotClub(.tee, at: 0) == club)
            #expect(state.slotDistance(.tee, at: 0) == expected[club])
        }
    }

    @Test("Putt badges use circular geometry while full shots stay rectangular")
    func threadNodeBadgeGeometry() {
        #expect(ThreadNodeBadgeShape(mode: .putt) == .circle)
        #expect(ThreadNodeBadgeShape(mode: .green) == .rectangle)
        #expect(ThreadNodeBadgeShape(mode: .fairway) == .rectangle)
    }

    private func pick(_ value: String?, good: Bool) -> TargetField.Pick {
        TargetField.Pick(
            value: value,
            pos: CGPoint(x: 0.5, y: 0.5),
            good: good,
            label: value ?? ""
        )
    }

    private func makeState() -> RoundPlayState {
        let pars = [4, 5, 3]
        let holes = pars.enumerated().map { offset, par in
            Hole(id: UUID(), externalId: UUID(), number: offset + 1, par: par, handicapIndex: offset + 1)
        }
        let teeHoles = (1...3).map { number in
            TeeHole(id: UUID(), externalId: UUID(), holeNumber: number, yardage: 350)
        }
        let tee = Tee(
            id: UUID(),
            externalId: UUID(),
            name: "White",
            courseRating: 71.2,
            slopeRating: 128,
            totalYardage: 1_050,
            teeHoles: teeHoles
        )
        let course = Course(
            id: UUID(),
            externalId: UUID(),
            userId: UUID(),
            name: "Fixture GC",
            location: "Nowhere",
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            tees: [tee],
            holes: holes
        )
        return RoundPlayState(course: course, teeId: tee.id, holesPlayed: .eighteen)
    }
}
