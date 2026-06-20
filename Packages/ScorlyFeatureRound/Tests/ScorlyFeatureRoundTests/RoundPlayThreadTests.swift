import Foundation
import ScorlyDesignSystem
import ScorlyDomain
import Testing
@testable import ScorlyFeatureRound

/// Integrity tests for "The Thread" projection. Each test logs a hole
/// through the new node write-helpers, then asserts `derivedStat` produces
/// the *same* `HoleStat` as the equivalent old-flow `HoleEntry` field
/// writes. `HoleStat` is `Equatable`, so a full-struct comparison checks
/// every stat at once: lies, penalties, putt distances, ARG shots, clubs,
/// GIR/FIR. This is the guard that the redesign loses no data.
@MainActor
struct RoundPlayThreadTests {
    // MARK: - Par 4 · fairway → green → 2-putt (par)

    @Test("Thread par-4 GIR two-putt matches old-flow HoleStat")
    func par4GIRTwoPutt() {
        let thread = makeState()
        let s = thread
        s.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        s.setSlotDistance(260, to: .tee, at: 0)
        s.setSlotClub("Driver", to: .tee, at: 0)
        s.applyPick(pick("Green", good: true), to: .approach, at: 0)
        s.setSlotDistance(150, to: .approach, at: 0)
        s.setSlotClub("7i", to: .approach, at: 0)
        s.setSlotDistance(18, to: .putt(0), at: 0)
        s.addPutt(after: .putt(0), at: 0)
        s.setSlotDistance(3, to: .putt(1), at: 0)
        s.applyPick(holedPutt, to: .putt(1), at: 0)

        let old = makeState()
        old.entries[0] = HoleEntry(
            strokes: 4, putts: 2, puttDistances: [18, 3],
            teeShot: "Fairway", teeClub: "Driver", teeShotDistance: 260,
            approach: "Green", approachClub: "7i", approachDistance: 150
        )

        let stat = thread.derivedStat(for: 0)
        #expect(stat == old.derivedStat(for: 0))
        #expect(stat.strokes == 4)
        #expect(stat.greenInRegulation)
        #expect(stat.fairwayInRegulation)
        #expect(stat.putts == 2)
    }

    // MARK: - Par 4 · GIR one-putt (birdie) — putts not stuck on the default 2

    @Test("Thread par-4 one-putt records putts == 1")
    func par4OnePutt() {
        let thread = makeState()
        thread.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        thread.applyPick(pick("Green", good: true), to: .approach, at: 0)
        thread.setSlotDistance(8, to: .putt(0), at: 0)
        thread.applyPick(holedPutt, to: .putt(0), at: 0)

        let old = makeState()
        old.entries[0] = HoleEntry(
            strokes: 3,
            putts: 1,
            puttDistances: [8],
            teeShot: "Fairway",
            teeShotDistance: 0,
            approach: "Green",
            approachDistance: 0
        )

        let stat = thread.derivedStat(for: 0)
        #expect(stat == old.derivedStat(for: 0))
        #expect(stat.putts == 1)
        #expect(stat.strokes == 3)
    }

    // MARK: - Par 4 · GIR three-putt (bogey)

    @Test("Thread par-4 three-putt records putts == 3 and threePutt")
    func par4ThreePutt() {
        let thread = makeState()
        thread.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        thread.applyPick(pick("Green", good: true), to: .approach, at: 0)
        thread.setSlotDistance(30, to: .putt(0), at: 0)
        thread.addPutt(after: .putt(0), at: 0)
        thread.setSlotDistance(5, to: .putt(1), at: 0)
        thread.addPutt(after: .putt(1), at: 0)
        thread.setSlotDistance(2, to: .putt(2), at: 0)
        thread.applyPick(holedPutt, to: .putt(2), at: 0)

        let old = makeState()
        old.entries[0] = HoleEntry(
            strokes: 5,
            putts: 3,
            puttDistances: [30, 5, 2],
            teeShot: "Fairway",
            teeShotDistance: 0,
            approach: "Green",
            approachDistance: 0
        )

        let stat = thread.derivedStat(for: 0)
        #expect(stat == old.derivedStat(for: 0))
        #expect(stat.putts == 3)
        #expect(stat.threePutt)
    }

    // MARK: - Par 3 · ace (holed tee shot)

    @Test("Thread par-3 ace matches old-flow and scores 1 with GIR")
    func par3Ace() {
        let thread = makeState()
        thread.setSlotDistance(165, to: .teeToGreen, at: 2)
        thread.setSlotClub("7i", to: .teeToGreen, at: 2)
        thread.holeOutShot(.teeToGreen, at: 2)

        let old = makeState()
        old.entries[2] = HoleEntry(
            strokes: 1,
            putts: 0,
            approach: "In",
            approachClub: "7i",
            approachDistance: 165
        )

        let stat = thread.derivedStat(for: 2)
        #expect(stat == old.derivedStat(for: 2))
        #expect(stat.strokes == 1)
        #expect(stat.putts == 0)
        #expect(stat.teeShotLie == .green)
        // The domain's GIR rule guards on `putts > 0`, so an ace (0 putts)
        // is deliberately not flagged GIR — pre-existing behavior, and the
        // Thread reproduces it exactly (the `== old` parity above holds).
        #expect(!stat.greenInRegulation)
    }

    // MARK: - Par 4 · missed green → chip-in

    @Test("Thread par-4 chip-in matches old-flow with an ARG shot")
    func par4ChipIn() {
        let thread = makeState()
        thread.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        thread.applyPick(pick("Miss Right", good: false), to: .approach, at: 0)
        thread.setSlotDistance(15, to: .chip(0), at: 0)
        thread.holeOutShot(.chip(0), at: 0)

        let old = makeState()
        old.entries[0] = HoleEntry(
            strokes: 3, putts: 0,
            teeShot: "Fairway", teeShotDistance: 0,
            approach: "Miss Right", approachDistance: 0,
            argShots: [ARGShotEntry(lie: "In", distanceYards: 15)]
        )

        let stat = thread.derivedStat(for: 0)
        #expect(stat == old.derivedStat(for: 0))
        #expect(stat.strokes == 3)
        #expect(stat.argShots?.count == 1)
        #expect(stat.approachLie == .recoveryRight)
    }

    // MARK: - Par 5 · fairway bunker tee → layup → green

    @Test("Thread par-5 with fairway bunker + layup matches old-flow")
    func par5LayupBunker() {
        let thread = makeState()
        thread.applyPick(pick("Miss Right", modifier: "Bunker", good: false), to: .tee, at: 1)
        thread.setSlotDistance(240, to: .tee, at: 1)
        thread.applyPick(pick("Fairway", good: true), to: .second, at: 1)
        thread.setSlotDistance(210, to: .second, at: 1)
        thread.applyPick(pick("Green", good: true), to: .approach, at: 1)
        thread.setSlotDistance(95, to: .approach, at: 1)
        thread.setSlotDistance(20, to: .putt(0), at: 1)
        thread.addPutt(after: .putt(0), at: 1)
        thread.setSlotDistance(2, to: .putt(1), at: 1)
        thread.applyPick(holedPutt, to: .putt(1), at: 1)

        let old = makeState()
        old.entries[1] = HoleEntry(
            strokes: 5, putts: 2, puttDistances: [20, 2],
            teeShot: "Miss Right", teeShotModifier: "Bunker", teeShotDistance: 240,
            approach: "Green", approachDistance: 95,
            layupLie: "Fairway", layupDistance: 210
        )

        let stat = thread.derivedStat(for: 1)
        #expect(stat == old.derivedStat(for: 1))
        #expect(stat.teeShotLie == .bunkerRight)
        #expect(stat.layupLie == .fairway)
        #expect(stat.greenInRegulation)
        #expect(!stat.fairwayInRegulation)
        #expect(stat.bunkerCount == 1)
    }

    // MARK: - Pin tap holes a green-mode shot

    @Test("Thread pin tap on an approach holes it out, matching the In flow")
    func par4PinTapHoles() {
        let thread = makeState()
        thread.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        let holedGreen = TargetField.Pick(
            value: "Green", pos: CGPoint(x: 0.5, y: 0.493), good: true,
            label: "HOLED", proximityFeet: 0, holed: true
        )
        thread.applyPick(holedGreen, to: .approach, at: 0)

        let old = makeState()
        old.entries[0] = HoleEntry(
            strokes: 2, putts: 0,
            teeShot: "Fairway", teeShotDistance: 0,
            approach: "In", approachDistance: 0
        )

        let stat = thread.derivedStat(for: 0)
        #expect(stat == old.derivedStat(for: 0))
        #expect(stat.strokes == 2)
        #expect(stat.putts == 0)
        #expect(thread.isSlotHoled(.approach, at: 0))
    }

    // MARK: - Hazard tag composes with the directional tap

    @Test("Bunker tag composes with a directional miss into a bunker lie")
    func bunkerComposesWithDirection() {
        let thread = makeState()
        thread.applyPick(pick("Miss Left", good: false), to: .tee, at: 1)
        thread.applyHazard(.bunker, to: .tee, at: 1)
        #expect(thread.derivedStat(for: 1).teeShotLie == .bunkerLeft)

        // Re-tapping the target clears the bunker (a fresh result).
        thread.applyPick(pick("Fairway", good: true), to: .tee, at: 1)
        #expect(thread.derivedStat(for: 1).teeShotLie == .fairway)
        #expect(thread.derivedStat(for: 1).bunkerCount == 0)
    }

    // MARK: - Tee OB direction preserved through the hazard tag

    @Test("Thread OB hazard tag records a directional penalty event")
    func teeOBDirection() {
        let thread = makeState()
        // Place the tee shot right, then tag it OB — direction flows through.
        thread.applyPick(pick("Miss Right", good: false), to: .tee, at: 0)
        thread.applyHazard(.ob, to: .tee, at: 0)

        let stat = thread.derivedStat(for: 0)
        #expect(stat.teeShotLie == nil)
        #expect(stat.outOfBoundsCount == 1)
        #expect(stat.penaltyEvents == [PenaltyEvent(kind: .outOfBounds, direction: .right, phase: .tee)])
    }

    @Test("Thread Water hazard tag records a hazard (not OB) event")
    func teeWaterDirection() {
        let thread = makeState()
        thread.applyPick(pick("Miss Left", good: false), to: .tee, at: 0)
        thread.applyHazard(.water, to: .tee, at: 0)

        let stat = thread.derivedStat(for: 0)
        #expect(stat.hazardCount == 1)
        #expect(stat.outOfBoundsCount == 0)
        #expect(stat.penaltyEvents == [PenaltyEvent(kind: .hazard, direction: .left, phase: .tee)])
    }

    @Test("Thread Unplayable tag bumps a manual penalty stroke")
    func unplayablePenalty() {
        let thread = makeState()
        thread.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        thread.applyHazard(.unplayable, to: .tee, at: 0)
        #expect(thread.derivedStat(for: 0).effectivePenaltyStrokes == 1)
    }

    // MARK: - Pin position survives

    @Test("Thread pin position writes through to HoleStat")
    func pinPositionPreserved() {
        let thread = makeState()
        thread.applyPick(pick("Green", good: true), to: .approach, at: 0)
        thread.setPinPosition("Back", at: 0)
        #expect(thread.derivedStat(for: 0).pinPosition == "Back")
    }

    // MARK: - Codec round-trip

    @Test("Entries logged through the Thread survive an encode/decode round-trip")
    func codecRoundTrip() {
        let thread = makeState()
        thread.applyPick(pick("Fairway", good: true), to: .tee, at: 0)
        thread.setSlotDistance(255, to: .tee, at: 0)
        thread.setSlotClub("Driver", to: .tee, at: 0)
        thread.applyPick(pick("Green", good: true), to: .approach, at: 0)
        thread.setSlotDistance(140, to: .approach, at: 0)
        thread.setSlotDistance(12, to: .putt(0), at: 0)
        thread.applyPick(holedPutt, to: .putt(0), at: 0)

        let data = HoleEntriesCodec.encode(thread.entries)
        let decoded = HoleEntriesCodec.decode(data)
        #expect(decoded == thread.entries)
    }

    // MARK: - Helpers

    private func pick(_ value: String?, modifier: String? = nil, good: Bool) -> TargetField.Pick {
        TargetField.Pick(
            value: value,
            pos: CGPoint(x: 0.5, y: 0.5),
            good: good,
            label: value ?? "",
            modifier: modifier
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
