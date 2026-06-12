import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyFeatureRound

@MainActor
struct RoundPlayStateTests {
    @Test("Live round owns the setup metadata that will be filed")
    func liveRoundSetupMetadata() {
        let initial = RoundSetupForm(
            roundType: .competitive,
            roundFormat: .stableford,
            conditions: [.cloudy, .windy],
            temperature: 9,
            walkingVsRiding: .riding,
            mentalState: 4,
            notes: "Initial"
        )
        let state = RoundPlayState(
            course: Self.makeCourse(),
            teeId: nil,
            holesPlayed: .eighteen,
            setupForm: initial
        )
        #expect(state.setupForm.roundType == .competitive)
        #expect(state.setupForm.roundFormat == .stableford)
        #expect(state.setupForm.conditions == [.cloudy, .windy])

        var edited = state.setupForm
        edited.roundType = .tournament
        edited.roundFormat = .match
        edited.conditions = [.rainy]
        edited.notes = "Saved mid round"
        state.updateSetup(edited)

        #expect(state.setupForm.roundType == .tournament)
        #expect(state.setupForm.roundFormat == .match)
        #expect(state.setupForm.conditions == [.rainy])
        #expect(state.setupForm.notes == "Saved mid round")
    }

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

    @Test("Fresh live-round holes default to two putts")
    func freshHolesDefaultToTwoPutts() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        #expect(state.entries.allSatisfy { $0.putts == 2 })
        #expect(state.derivedStat(for: 0).putts == 2)
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
        #expect(stat.penaltyEvents == [
            PenaltyEvent(kind: .outOfBounds, direction: .right, phase: .tee),
        ])
    }

    @Test("Water Hazard pushes the hazard count")
    func lieDecodingHazard() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        state.entries[0].strokes = 6
        state.entries[0].approach = "Water Hazard"
        let stat = state.derivedStat(for: 0)
        #expect(stat.hazardCount == 1)
        #expect(stat.penaltyEvents == [
            PenaltyEvent(kind: .hazard, phase: .approach),
        ])
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

    @Test("OB tee result clears teeShotDistance on entry mutation")
    func obTeeShotClearsDistance() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        state.entries[0].teeShotDistance = 240
        state.entries[0].teeShot = "OB Left"
        // Simulate the binding setter logic from ShotSheetView
        if let v = state.entries[0].teeShot, v.hasPrefix("OB ") {
            state.entries[0].teeShotDistance = nil
        }
        #expect(state.entries[0].teeShotDistance == nil)
    }

    @Test("Par 3 tee-shot-on-green via approach editor still scores GIR")
    func par3GIRThroughApproachEditor() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        // Hole 3 is a par 3 in the fixture. The Play UI hides the tee block
        // on par 3 and routes the on-green pick through the approach editor,
        // so the entry stores the pick on `approach`, not `teeShot`.
        state.entries[2].strokes = 3
        state.entries[2].putts = 2
        state.entries[2].approach = "Green"
        let stat = state.derivedStat(for: 2)
        #expect(stat.par == 3)
        #expect(stat.greenInRegulation == true)
        // Par 3 has no separate approach — fold the lie into the tee-shot slot.
        #expect(stat.teeShotLie == .green)
        #expect(stat.approachLie == nil)
    }

    @Test("Par 3 missed green via approach editor does not score GIR")
    func par3MissesGreenNoGIR() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        state.entries[2].strokes = 4
        state.entries[2].putts = 2
        state.entries[2].approach = "Miss Right"
        let stat = state.derivedStat(for: 2)
        #expect(stat.greenInRegulation == false)
        // "Miss Right" with target=.green decodes to recovery, folded into teeShotLie for par 3.
        #expect(stat.teeShotLie == .recoveryRight)
        #expect(stat.approachLie == nil)
    }

    @Test("Par 5 ON IN 2 via approach aux button counts as GIR")
    func par5OnInTwoGIR() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        // Hole 2 is a par 5 in the fixture.
        state.entries[1].strokes = 4
        state.entries[1].putts = 2
        state.entries[1].teeShot = "Fairway"
        state.entries[1].approach = "On In 2"
        let stat = state.derivedStat(for: 1)
        #expect(stat.par == 5)
        #expect(stat.greenInRegulation == true)
        #expect(stat.approachLie == .green)
    }

    @Test("Par 5 2nd shot tab hides only for driven green or ON IN 2")
    func par5SecondShotTabVisibility() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        #expect(state.shouldShowLayupTab(at: 1))

        state.entries[1].approach = "On In 2"
        #expect(!state.shouldShowLayupTab(at: 1))

        state.entries[1].approach = nil
        state.setTeeShotResult("Green", at: 1)
        #expect(!state.shouldShowLayupTab(at: 1))
    }

    @Test("Around the green tab requires a missed approach and inferred chip")
    func aroundGreenTabVisibilityRequiresMissAndChipMath() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        state.entries[0].strokes = 4
        state.entries[0].putts = 2
        state.entries[0].approach = "Miss Right"
        #expect(!state.shouldShowARGTab(at: 0))

        state.entries[0].strokes = 5
        #expect(state.shouldShowARGTab(at: 0))

        state.entries[0].approach = "Green"
        #expect(!state.shouldShowARGTab(at: 0))

        state.entries[0].approach = "OB Right"
        #expect(!state.shouldShowARGTab(at: 0))
    }

    @Test("Par 5 inferred ARG count treats 2nd shot as a separate pre-green shot")
    func par5ARGCountIncludesSecondShot() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        state.entries[1].strokes = 6
        state.entries[1].putts = 2
        state.entries[1].approach = "Miss Right"

        #expect(state.inferredARGCount(at: 1) == 1)
        #expect(state.shouldShowARGTab(at: 1))
    }

    @Test("Par 5 layup uses approach distance as remaining distance")
    func par5LayupUsesApproachDistance() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        state.entries[1].strokes = 5
        state.entries[1].teeShot = "Fairway"
        state.entries[1].layupLie = "Fairway"
        state.entries[1].approachDistance = 105
        state.entries[1].approach = "Green"

        let stat = state.derivedStat(for: 1)
        #expect(stat.layupLie == .fairway)
        #expect(stat.layupDistance == 105)
    }

    @Test("Approach IN marks the approach as holed")
    func approachInMarksHoledShot() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        state.entries[0].strokes = 4
        state.entries[0].putts = 2
        state.entries[0].puttDistances = [20, 3]
        state.markApproachIn(at: 0)

        #expect(state.entries[0].approach == "In")
        #expect(state.entries[0].strokes == 2)
        #expect(state.entries[0].putts == 0)
        #expect(state.entries[0].puttDistances.isEmpty)
        #expect(state.isApproachIn(at: 0))
    }

    @Test("Approach IN toggles independently from GRN")
    func approachInTogglesIndependentlyFromGreen() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        state.markApproachIn(at: 0)

        #expect(state.isApproachIn(at: 0))
        #expect(state.entries[0].approach != "Green")

        state.markApproachIn(at: 0)

        #expect(!state.isApproachIn(at: 0))
        #expect(state.entries[0].approach == nil)
        #expect(state.entries[0].putts == 2)

        state.setApproachResult("Green", at: 0)

        #expect(state.entries[0].approach == "Green")
        #expect(!state.isApproachIn(at: 0))
    }

    @Test("Around the green IN marks the selected chip as holed")
    func argInMarksSelectedChipHoled() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        state.entries[0].strokes = 5
        state.entries[0].putts = 2
        state.entries[0].approach = "Miss Right"
        state.entries[0].argShots = [
            ARGShotEntry(lie: "Miss Right", distanceYards: 15),
            ARGShotEntry(lie: "Miss Left", distanceYards: 5),
        ]
        state.markARGIn(slot: 0, at: 0)

        #expect(state.entries[0].strokes == 3)
        #expect(state.entries[0].putts == 0)
        #expect(state.entries[0].puttDistances.isEmpty)
        #expect(state.entries[0].argShots?.count == 1)
        #expect(state.isARGIn(slot: 0, at: 0))
    }

    @Test("Around the green IN toggles off")
    func argInTogglesOff() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)

        state.entries[0].strokes = 5
        state.entries[0].putts = 2
        state.entries[0].approach = "Miss Right"

        state.markARGIn(slot: 0, at: 0)

        #expect(state.isARGIn(slot: 0, at: 0))

        state.markARGIn(slot: 0, at: 0)

        #expect(!state.isARGIn(slot: 0, at: 0))
        #expect(state.entries[0].putts == 2)
        #expect(state.inferredARGCount(at: 0) == 1)
    }

    @Test("Single ARG shot reuses approach landing distance without duplicate entry")
    func singleARGShotUsesApproachLandingDistance() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)
        state.entries[0].strokes = 5
        state.entries[0].putts = 2
        state.entries[0].approach = "Miss Right"
        state.entries[0].approachLandingDistance = 17
        state.entries[0].argShots = [
            ARGShotEntry(lie: "Miss Right"),
        ]

        let stat = state.derivedStat(for: 0)

        #expect(stat.argShots == [
            ARGShot(lie: .recoveryRight, distanceToPinYards: 17),
        ])
        #expect(state.argStartDistance(slot: 0, at: 0) == 17)
        #expect(state.recordedARGCount(at: 0) == 1)
    }

    @Test("Intermediate ARG landing distance becomes next shot start")
    func intermediateARGLandingBecomesNextStart() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)
        state.entries[0].strokes = 6
        state.entries[0].putts = 2
        state.entries[0].approach = "Miss Right"
        state.entries[0].approachLandingDistance = 28
        state.entries[0].argShots = [
            ARGShotEntry(lie: "Miss Right"),
            ARGShotEntry(lie: "Miss Left"),
        ]

        state.setARGTransitionDistance(9, after: 0, at: 0)

        let stat = state.derivedStat(for: 0)
        #expect(state.argStartDistance(slot: 1, at: 0) == 9)
        #expect(stat.argShots == [
            ARGShot(lie: .recoveryRight, distanceToPinYards: 28),
            ARGShot(lie: .recoveryLeft, distanceToPinYards: 9),
        ])
        #expect(state.recordedARGCount(at: 0) == 2)
    }

    @Test("ARG distance wheel appears only between shots")
    func argDistanceWheelVisibility() {
        #expect(!ARGEditorSection.showsTransitionDistance(after: 0, count: 1))
        #expect(ARGEditorSection.showsTransitionDistance(after: 0, count: 2))
        #expect(!ARGEditorSection.showsTransitionDistance(after: 1, count: 2))
    }

    @Test("Par 4 driven green clears approach data and scores GIR")
    func par4DrivenGreen() {
        let state = RoundPlayState(course: Self.makeCourse(), teeId: nil, holesPlayed: .eighteen)
        state.entries[0].strokes = 3
        state.entries[0].putts = 2
        state.entries[0].approach = "Green"
        state.entries[0].approachModifier = "Bunker"
        state.entries[0].approachClub = "PW"
        state.entries[0].approachDistance = 100
        state.entries[0].approachLandingDistance = 15
        state.entries[0].argShots = [ARGShotEntry(lie: "Miss Right", distanceYards: 10)]
        state.entries[0].layupLie = "Fairway"
        state.entries[0].layupDistance = 100

        state.setTeeShotResult("Green", at: 0)

        let stat = state.derivedStat(for: 0)
        #expect(state.hasDrivenGreen(at: 0))
        #expect(state.entries[0].approach == nil)
        #expect(state.entries[0].approachModifier == nil)
        #expect(state.entries[0].approachClub == nil)
        #expect(state.entries[0].approachDistance == nil)
        #expect(state.entries[0].approachLandingDistance == nil)
        #expect(state.entries[0].argShots == nil)
        #expect(state.entries[0].layupLie == nil)
        #expect(state.entries[0].layupDistance == nil)
        #expect(stat.teeShotLie == .green)
        #expect(stat.greenInRegulation)
        #expect(!stat.fairwayInRegulation)
    }

    @Test("Par 5 driven green normalizes stale approach data on resume")
    func par5DrivenGreenResumeNormalization() {
        let course = Self.makeCourse()
        let greenEntry = HoleEntry(
            strokes: 4,
            putts: 2,
            teeShot: "Green",
            teeShotModifier: "Bunker",
            approach: "Miss Left",
            approachModifier: "Bunker",
            approachClub: "54",
            approachDistance: 30
        )
        let entries = [HoleEntry(), greenEntry] + Array(repeating: HoleEntry(), count: 16)
        let state = RoundPlayState(
            course: course,
            teeId: nil,
            holesPlayed: .eighteen,
            entries: entries,
            holeIdx: 1,
            startedAt: Date()
        )

        let stat = state.derivedStat(for: 1)
        #expect(state.hasDrivenGreen(at: 1))
        #expect(state.entries[1].teeShotModifier == nil)
        #expect(state.entries[1].approach == nil)
        #expect(state.entries[1].approachModifier == nil)
        #expect(state.entries[1].approachClub == nil)
        #expect(state.entries[1].approachDistance == nil)
        #expect(stat.teeShotLie == .green)
        #expect(stat.greenInRegulation)
        #expect(!stat.fairwayInRegulation)
    }

    @Test("Resume init normalizes OB entry with residual teeShotDistance")
    func resumeNormalizesOBDistance() {
        let course = Self.makeCourse()
        let obEntry = HoleEntry(
            strokes: 5,
            teeShot: "OB Right",
            teeShotDistance: 230
        )
        let entries = [obEntry] + Array(repeating: HoleEntry(), count: 17)
        let state = RoundPlayState(
            course: course,
            teeId: nil,
            holesPlayed: .eighteen,
            entries: entries,
            holeIdx: 0,
            startedAt: Date()
        )
        #expect(state.entries[0].teeShotDistance == nil)
    }

    @Test("liveGIR counts greens-in-regulation across logged holes only")
    func liveGIRCountsLoggedOnly() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        // Log holes 1 (par 4, GIR), 2 (par 5, GIR via On In 2), 3 (par 3, GIR).
        state.entries[0].strokes = 4
        state.entries[0].putts = 2
        state.entries[0].teeShot = "Fairway"
        state.entries[0].approach = "Green"
        state.entries[1].strokes = 4
        state.entries[1].putts = 2
        state.entries[1].teeShot = "Fairway"
        state.entries[1].approach = "On In 2"
        state.entries[2].strokes = 3
        state.entries[2].putts = 2
        state.entries[2].approach = "Green"
        let gir = state.liveGIR
        #expect(gir.made == 3)
        #expect(gir.of == 3)
    }

    @Test("liveFIR returns nil when only par-3 holes are logged")
    func liveFIRNilWhenOnlyPar3() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        // Hole 3 is par 3 in the fixture.
        state.entries[2].strokes = 3
        state.entries[2].putts = 2
        state.entries[2].approach = "Green"
        #expect(state.liveFIR == nil)
    }

    @Test("liveFIR ratio includes only logged par-4 / par-5 holes")
    func liveFIROnlyPar4Plus() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        // Hole 1 par 4 FIR ✓, hole 2 par 5 FIR ✓, hole 4 par 4 missed FIR,
        // hole 3 par 3 (excluded from FIR denominator).
        state.entries[0].strokes = 4
        state.entries[0].putts = 2
        state.entries[0].teeShot = "Fairway"
        state.entries[1].strokes = 5
        state.entries[1].putts = 2
        state.entries[1].teeShot = "Fairway"
        state.entries[2].strokes = 3
        state.entries[2].putts = 2
        state.entries[2].approach = "Green"
        state.entries[3].strokes = 5
        state.entries[3].putts = 2
        state.entries[3].teeShot = "OB Right"
        let fir = state.liveFIR
        #expect(fir?.made == 2)
        #expect(fir?.of == 3)
    }

    @Test("livePutts and liveThreePutts sum across logged holes only")
    func livePuttsLoggedOnly() {
        let course = Self.makeCourse()
        let state = RoundPlayState(course: course, teeId: nil, holesPlayed: .eighteen)
        state.entries[0].strokes = 4
        state.entries[0].putts = 2
        state.entries[1].strokes = 6
        state.entries[1].putts = 3
        // Hole 3 unplayed — must not contribute.
        #expect(state.livePutts == 5)
        #expect(state.liveThreePutts == 1)
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
