import Foundation
import ScorlyDesignSystem
import ScorlyDomain
import Testing
@testable import ScorlyFeatureRound

@MainActor
struct RoundPlayRadarInputTests {
    @Test("Setting a putt length does not default the putt to holed")
    func puttLengthDoesNotDefaultToHoled() {
        let state = makeState()
        reachGreen(state)

        state.setSlotDistance(8, to: .putt(0), at: 0)

        let putt = state.threadNodes(at: 0).first { $0.slot == .putt(0) }
        #expect(putt?.good == false)
        #expect(putt?.resultLabel == "8 FT")
        #expect(!state.isHoleComplete(at: 0))
    }

    @Test("Each missed putt automatically appends one pending putt")
    func missedPuttsAppendPendingPutt() {
        let state = makeState()
        reachGreen(state)

        state.applyPick(
            pick(nil, at: CGPoint(x: 0.65, y: 0.5), good: false, proximityFeet: 5),
            to: .putt(0),
            at: 0
        )
        state.applyPick(
            pick(nil, at: CGPoint(x: 0.55, y: 0.5), good: false, proximityFeet: 2),
            to: .putt(1),
            at: 0
        )

        #expect(state.threadNodes(at: 0).contains { $0.slot == .putt(2) })
        #expect(state.entries[0].puttCompletionState == .open)
        #expect(!state.isHoleComplete(at: 0))
    }

    @Test("Only an explicit holed putt completes putting")
    func explicitHoledPuttCompletesPutting() {
        let state = makeState()
        reachGreen(state)
        state.setSlotDistance(8, to: .putt(0), at: 0)

        state.applyPick(holedPutt, to: .putt(0), at: 0)

        #expect(state.entries[0].puttCompletionState == .holed)
        #expect(state.isHoleComplete(at: 0))
        #expect(state.threadNodes(at: 0).first { $0.slot == .putt(0) }?.good == true)
    }

    @Test("Hazard categories preserve an existing radar marker")
    func hazardPreservesRadarMarker() {
        let state = makeState()
        let position = CGPoint(x: 0.18, y: 0.72)
        state.applyPick(pick("Miss Left", at: position, good: false), to: .tee, at: 0)

        state.applyHazard(.bunker, to: .tee, at: 0)

        #expect(state.entries[0].teeTargetPosition?.point == position)
        #expect(state.threadNodes(at: 0)[0].placement?.pos == position)
    }

    @Test("Hazard category selected before a radar tap creates no marker")
    func hazardBeforeRadarCreatesNoMarker() {
        let state = makeState()

        state.applyHazard(.ob, to: .tee, at: 0)

        #expect(state.entries[0].teeTargetPosition == nil)
        #expect(state.threadNodes(at: 0)[0].placement == nil)
        #expect(state.derivedStat(for: 0).outOfBoundsCount == 1)
    }

    @Test("Long tee miss tagged OB preserves and displays its direction")
    func longOBPreservesDirection() {
        let state = makeState()
        state.applyPick(pick("Miss Long", at: CGPoint(x: 0.5, y: 0.12), good: false), to: .tee, at: 0)

        state.applyHazard(.ob, to: .tee, at: 0)

        #expect(state.entries[0].teeShot == "OB Long")
        #expect(state.threadNodes(at: 0)[0].resultLabel == "OB LONG")
    }

    @Test("Exact radar positions persist for every shot slot and through the codec")
    func exactRadarPositionsPersist() {
        let state = makeState()
        state.applyPick(pick("Miss Left", at: CGPoint(x: 0.21, y: 0.33), good: false), to: .tee, at: 1)
        state.applyPick(pick("Fairway", at: CGPoint(x: 0.62, y: 0.41), good: true), to: .second, at: 1)
        state.applyPick(pick("Miss Short", at: CGPoint(x: 0.47, y: 0.88), good: false), to: .approach, at: 1)
        state.applyPick(pick("Green", at: CGPoint(x: 0.39, y: 0.46), good: true), to: .chip(0), at: 1)
        state.applyPick(
            pick(nil, at: CGPoint(x: 0.71, y: 0.57), good: false, proximityFeet: 7),
            to: .putt(0),
            at: 1
        )

        let entry = state.entries[1]
        #expect(entry.teeTargetPosition?.point == CGPoint(x: 0.21, y: 0.33))
        #expect(entry.layupTargetPosition?.point == CGPoint(x: 0.62, y: 0.41))
        #expect(entry.approachTargetPosition?.point == CGPoint(x: 0.47, y: 0.88))
        #expect(entry.argShots?[0].targetPosition?.point == CGPoint(x: 0.39, y: 0.46))
        #expect(entry.puttTargetPositions?[0]?.point == CGPoint(x: 0.71, y: 0.57))

        let decoded = HoleEntriesCodec.decode(HoleEntriesCodec.encode(state.entries))
        #expect(decoded?[1] == entry)
        #expect(decoded?[1].puttTargetPositions?[0]?.point == CGPoint(x: 0.71, y: 0.57))
    }

    @Test("Drafts saved before radar positions still decode")
    func legacyDraftWithoutRadarPositionsDecodes() throws {
        let json = Data(#"[{"putts":2,"puttDistances":[],"penaltyStrokes":0}]"#.utf8)
        let decoded = try JSONDecoder().decode([HoleEntry].self, from: json)

        #expect(decoded.count == 1)
        #expect(decoded[0].puttTargetPositions == nil)
        #expect(decoded[0].puttCompletionState == nil)
    }

    private func reachGreen(_ state: RoundPlayState) {
        state.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        state.applyPick(pick("Green", good: true), to: .approach, at: 0)
    }

    private func pick(
        _ value: String?,
        at position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        good: Bool,
        proximityFeet: Int? = nil
    ) -> TargetField.Pick {
        TargetField.Pick(
            value: value,
            pos: position,
            good: good,
            label: value ?? "",
            proximityFeet: proximityFeet
        )
    }

    private var holedPutt: TargetField.Pick {
        TargetField.Pick(
            value: nil,
            pos: CGPoint(x: 0.5, y: 0.493),
            good: true,
            label: "HOLED",
            proximityFeet: 0,
            holed: true
        )
    }

    private func makeState() -> RoundPlayState {
        RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)
    }

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
            totalYardage: 6_300,
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
