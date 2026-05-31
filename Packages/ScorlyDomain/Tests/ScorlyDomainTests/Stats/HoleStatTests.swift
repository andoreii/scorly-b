import Foundation
import Testing
@testable import ScorlyDomain

struct HoleStatTests {
    // MARK: - Lie.isBunker

    @Test("Lie.isBunker returns true for all four bunker variants only")
    func bunkerLieClassification() {
        #expect(Lie.bunkerLeft.isBunker)
        #expect(Lie.bunkerRight.isBunker)
        #expect(Lie.bunkerShort.isBunker)
        #expect(Lie.bunkerLong.isBunker)
        // Spot-check non-bunker cases — all 8 should be false.
        let bunkerNames = Set(["Bunker Left", "Bunker Right", "Bunker Short", "Bunker Long"])
        for lie in Lie.allCases where !bunkerNames.contains(lie.rawValue) {
            #expect(!lie.isBunker, "\(lie) should not be a bunker")
        }
    }

    // MARK: - bunkerCount

    @Test("bunkerCount counts tee + approach bunkers independently")
    func bunkerCountCombines() {
        #expect(stat(par: 4, strokes: 5, putts: 2).bunkerCount == 0)
        #expect(stat(par: 4, strokes: 5, putts: 2, tee: .bunkerLeft).bunkerCount == 1)
        #expect(stat(par: 4, strokes: 5, putts: 2, approach: .bunkerRight).bunkerCount == 1)
        #expect(stat(par: 4, strokes: 5, putts: 2, tee: .bunkerLeft, approach: .bunkerShort).bunkerCount == 2)
        // Non-bunker lies don't count.
        #expect(stat(par: 4, strokes: 5, putts: 2, tee: .fairway, approach: .roughLeft).bunkerCount == 0)
    }

    // MARK: - greenInRegulation

    @Test("Par 3 GIR requires tee shot on green AND strokes-putts ≤ 1")
    func par3GIR() {
        // Standard GIR: tee on green, 1 putt → 2 strokes, 1 putt → 2-1=1 ≤ 1 ✓
        #expect(stat(par: 3, strokes: 3, putts: 2, tee: .green).greenInRegulation)
        // Tee on fairway → no GIR even at par.
        #expect(!stat(par: 3, strokes: 3, putts: 2, tee: .fairway).greenInRegulation)
        // Tee unset → no GIR.
        #expect(!stat(par: 3, strokes: 3, putts: 2).greenInRegulation)
        // Triple bogey: tee → green but 4 strokes / 1 putt → 3 > 1, fails.
        #expect(!stat(par: 3, strokes: 4, putts: 1, tee: .green).greenInRegulation)
    }

    @Test("Par 4 GIR requires approach on green AND strokes-putts ≤ 2")
    func par4GIR() {
        // 4 strokes / 2 putts → 2 ≤ 2 ✓
        #expect(stat(par: 4, strokes: 4, putts: 2, approach: .green).greenInRegulation)
        // 5 strokes / 2 putts → 3 > 2, fails (chipped on after missed approach).
        #expect(!stat(par: 4, strokes: 5, putts: 2, approach: .green).greenInRegulation)
        // Approach to rough → no GIR.
        #expect(!stat(par: 4, strokes: 4, putts: 2, approach: .roughLeft).greenInRegulation)
        // A tee shot elsewhere does not replace a recorded approach result.
        #expect(!stat(par: 4, strokes: 4, putts: 2, tee: .roughLeft, approach: .fairway).greenInRegulation)
    }

    @Test("Par 5 GIR requires approach on green AND strokes-putts ≤ 3")
    func par5GIR() {
        // 5 strokes / 2 putts → 3 ≤ 3 ✓
        #expect(stat(par: 5, strokes: 5, putts: 2, approach: .green).greenInRegulation)
        // 6 strokes / 2 putts → 4 > 3, fails.
        #expect(!stat(par: 5, strokes: 6, putts: 2, approach: .green).greenInRegulation)
    }

    @Test("Par 4 and par 5 driven greens count as GIR without FIR")
    func drivenGreenGIR() {
        let par4 = stat(par: 4, strokes: 3, putts: 2, tee: .green)
        let par5 = stat(par: 5, strokes: 4, putts: 2, tee: .green)
        #expect(par4.greenInRegulation)
        #expect(par5.greenInRegulation)
        #expect(!par4.fairwayInRegulation)
        #expect(!par5.fairwayInRegulation)
    }

    @Test("GIR returns false when strokes or putts unset (hole not played)")
    func girGuardsAgainstUnplayedHoles() {
        #expect(!stat(par: 4, strokes: 0, putts: 0, approach: .green).greenInRegulation)
        #expect(!stat(par: 4, strokes: 4, putts: 0, approach: .green).greenInRegulation)
        // putts > strokes is nonsensical; guard rejects it.
        #expect(!stat(par: 4, strokes: 1, putts: 2, approach: .green).greenInRegulation)
    }

    // MARK: - fairwayInRegulation

    @Test("FIR requires par 4+ AND tee shot on fairway")
    func firRules() {
        // Par 3: never FIR even with tee on fairway.
        #expect(!stat(par: 3, strokes: 3, putts: 1, tee: .fairway).fairwayInRegulation)
        // Par 4 fairway ✓
        #expect(stat(par: 4, strokes: 4, putts: 2, tee: .fairway).fairwayInRegulation)
        // Par 5 fairway ✓
        #expect(stat(par: 5, strokes: 5, putts: 2, tee: .fairway).fairwayInRegulation)
        // Par 4 rough/bunker/recovery → no FIR.
        #expect(!stat(par: 4, strokes: 4, putts: 2, tee: .roughLeft).fairwayInRegulation)
        #expect(!stat(par: 4, strokes: 5, putts: 2, tee: .bunkerRight).fairwayInRegulation)
        #expect(!stat(par: 4, strokes: 5, putts: 2, tee: .recoveryShort).fairwayInRegulation)
        // Tee unset → no FIR.
        #expect(!stat(par: 4, strokes: 4, putts: 2).fairwayInRegulation)
    }

    // MARK: - threePutt

    @Test("3-putt fires at 3+ putts regardless of total strokes or par")
    func threePuttCounts() {
        #expect(!stat(par: 4, strokes: 4, putts: 0).threePutt)
        #expect(!stat(par: 4, strokes: 4, putts: 1).threePutt)
        #expect(!stat(par: 4, strokes: 5, putts: 2).threePutt)
        #expect(stat(par: 4, strokes: 6, putts: 3).threePutt)
        #expect(stat(par: 5, strokes: 8, putts: 4).threePutt)
    }

    // MARK: - upAndDown

    @Test("Up-and-down fires when GIR missed, 1 putt, score ≤ par")
    func upAndDownAutoRule() {
        // Par 4: tee=fairway, approach=rough (missed GIR), strokes=4 / putts=1 ✓
        #expect(stat(par: 4, strokes: 4, putts: 1, tee: .fairway, approach: .roughLeft).upAndDown)
        // Par 4: missed GIR, 1 putt, but bogey → fails ≤ par check.
        #expect(!stat(par: 4, strokes: 5, putts: 1, tee: .fairway, approach: .roughLeft).upAndDown)
        // Par 4 GIR with 1 putt → not up-and-down (it's just a birdie).
        #expect(!stat(par: 4, strokes: 3, putts: 1, approach: .green).upAndDown)
        // Par 4 missed GIR, 2 putts → not up-and-down.
        #expect(!stat(par: 4, strokes: 4, putts: 2, approach: .roughLeft).upAndDown)
    }

    @Test("Up-and-down manual override wins even when auto-rule wouldn't fire")
    func upAndDownManualOverride() {
        // Chip-in: 0 putts, missed GIR. Auto-rule fails (putts != 1), but
        // ticking the override marks it as up-and-down.
        #expect(stat(par: 4, strokes: 3, putts: 0, tee: .fairway, approach: .roughLeft, upAndDown: true).upAndDown)
        // Override beats a clean GIR too — silly but the contract is "if
        // the user said yes, it's yes".
        #expect(stat(par: 4, strokes: 4, putts: 2, approach: .green, upAndDown: true).upAndDown)
    }

    // MARK: - sandSave

    @Test("Sand save fires when bunker recorded, 1 putt, score ≤ par")
    func sandSaveAutoRule() {
        // Par 4: approach into bunker, 1 putt, par → save ✓
        #expect(stat(par: 4, strokes: 4, putts: 1, tee: .fairway, approach: .bunkerLeft).sandSave)
        // Tee in bunker also counts as a bunker shot for the rule.
        #expect(stat(par: 4, strokes: 4, putts: 1, tee: .bunkerRight, approach: .green).sandSave)
        // Bogey from a bunker → not a save.
        #expect(!stat(par: 4, strokes: 5, putts: 1, approach: .bunkerLeft).sandSave)
        // No bunker recorded → not a save even at par with 1 putt.
        #expect(!stat(par: 4, strokes: 4, putts: 1, approach: .roughLeft).sandSave)
        // 2 putts from a bunker → not a save (auto-rule wants exactly 1).
        #expect(!stat(par: 4, strokes: 5, putts: 2, approach: .bunkerLeft).sandSave)
    }

    @Test("Sand save manual override wins even when auto-rule wouldn't fire")
    func sandSaveManualOverride() {
        // Holed bunker shot (0 putts) — auto-rule fails on putts != 1.
        #expect(stat(par: 4, strokes: 3, putts: 0, approach: .bunkerLeft, sandSave: true).sandSave)
    }

    // MARK: - effectivePenaltyStrokes

    @Test("Effective penalty strokes take max of manual vs OB+hazard count")
    func effectivePenaltyMaxRule() {
        // Manual entry only.
        #expect(stat(par: 4, strokes: 6, putts: 2, penalty: 2).effectivePenaltyStrokes == 2)
        // OB only: 1 OB + 0 hazard = 1.
        #expect(stat(par: 4, strokes: 6, putts: 2, ob: 1).effectivePenaltyStrokes == 1)
        // Hazard only.
        #expect(stat(par: 4, strokes: 5, putts: 2, hazard: 1).effectivePenaltyStrokes == 1)
        // OB + hazard sum.
        #expect(stat(par: 4, strokes: 7, putts: 2, ob: 1, hazard: 1).effectivePenaltyStrokes == 2)
        // Manual beats auto when higher (player typed +3).
        #expect(stat(par: 4, strokes: 8, putts: 2, penalty: 3, ob: 1, hazard: 1).effectivePenaltyStrokes == 3)
        // Auto beats manual when higher (no manual, two OBs ticked).
        #expect(stat(par: 4, strokes: 8, putts: 2, penalty: 0, ob: 2, hazard: 0).effectivePenaltyStrokes == 2)
        // Equal: max returns the same value.
        #expect(stat(par: 4, strokes: 7, putts: 2, penalty: 2, ob: 1, hazard: 1).effectivePenaltyStrokes == 2)
        // No penalties at all.
        #expect(stat(par: 4, strokes: 4, putts: 2).effectivePenaltyStrokes == 0)
    }

    // MARK: - Codable round-trip

    @Test("HoleStat round-trips through JSON unchanged")
    func codableRoundTrip() throws {
        let original = stat(
            par: 5,
            strokes: 6,
            putts: 2,
            tee: .fairway,
            approach: .bunkerLeft,
            penalty: 1,
            ob: 1,
            hazard: 0,
            upAndDown: false,
            sandSave: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HoleStat.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Helpers

    /// Compact factory so test bodies stay readable. All defaults match
    /// the `HoleStat.init` defaults except `par`, `strokes`, `putts` which
    /// are required.
    private func stat(
        par: Int,
        strokes: Int,
        putts: Int,
        tee: Lie? = nil,
        approach: Lie? = nil,
        penalty: Int = 0,
        ob: Int = 0,
        hazard: Int = 0,
        upAndDown: Bool = false,
        sandSave: Bool = false
    ) -> HoleStat {
        let events: [PenaltyEvent] =
            Array(repeating: PenaltyEvent(kind: .outOfBounds), count: ob)
            + Array(repeating: PenaltyEvent(kind: .hazard), count: hazard)
        return HoleStat(
            par: par,
            strokes: strokes,
            putts: putts,
            teeShotLie: tee,
            approachLie: approach,
            penaltyStrokes: penalty,
            penaltyEvents: events,
            upAndDownSuccess: upAndDown,
            sandSaveSuccess: sandSave
        )
    }
}
