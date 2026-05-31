import ScorlyDomain
import Testing
@testable import ScorlyData

struct HoleStatStorageProjectionTests {
    @Test("Water approach persists its direction and automatic penalty stroke")
    func waterApproachProjection() {
        let storage = HoleStatStorageProjection(HoleStat(
            par: 4,
            strokes: 5,
            putts: 2,
            penaltyEvents: [
                PenaltyEvent(kind: .hazard, direction: .short, phase: .approach),
            ]
        ))

        #expect(storage.approach == "Short water")
        #expect(storage.penaltyStrokes == 1)
    }

    @Test("Par-3 OB input persists only on the approach field")
    func par3OBProjection() {
        let storage = HoleStatStorageProjection(HoleStat(
            par: 3,
            strokes: 5,
            putts: 2,
            penaltyEvents: [
                PenaltyEvent(kind: .outOfBounds, direction: .left, phase: .approach),
            ]
        ))

        #expect(storage.teeShot == nil)
        #expect(storage.approach == "Out Left")
        #expect(storage.penaltyStrokes == 1)
    }

    @Test("Legacy penalty JSON without phase remains readable")
    func legacyPenaltyJSONDecodesWithoutPhase() {
        let events = PenaltyEventJSONCodec.decode(
            #"[{"kind":"outOfBounds","direction":"left"}]"#
        )

        #expect(events == [
            PenaltyEvent(kind: .outOfBounds, direction: .left),
        ])
    }
}
