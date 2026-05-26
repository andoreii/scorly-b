import Foundation

/// One hole's worth of recorded play. The minimum input the rest of the
/// app needs to derive per-hole stats (GIR, FIR, 3-putt, up-and-down,
/// sand save, effective penalty strokes).
///
/// This is the v2 equivalent of v1's `HoleStat` in `RoundTrackerView.swift`.
/// Two intentional shape changes from v1:
///
/// 1. v1 stored `teeShot` and `approach` as free-form `String?` because
///    the same field encoded both lies (`"Fairway"`, `"Bunker Left"`) and
///    ball-result markers (`"Out Left"`, `"Left water"`). v2 splits those
///    concerns: `teeShotLie` / `approachLie` are typed `Lie?` (only valid
///    *playable* lies), and OB / hazard outcomes get their own integer
///    counts (`outOfBoundsCount`, `hazardCount`).
///
/// 2. v1 derived `bunkerCount` from string prefixes; v2 derives it from
///    the `Lie` enum via `Lie.isBunker`. Same semantics, type-safe.
///
/// All derivations are pure computed properties so a HoleStat is fully
/// described by its stored fields — no caching, no view-layer state.
public struct HoleStat: Sendable, Equatable, Codable {
    /// Hole par (3, 4, or 5 in standard play). Stored, not derived,
    /// because the same `HoleStat` shape is used in tests where the par
    /// isn't tied to a `Hole` model yet.
    public let par: Int
    /// Total strokes taken on the hole, **including** putts and any
    /// penalty strokes the player chose to enter.
    public let strokes: Int
    /// Number of strokes taken from the green. Putts are counted in
    /// `strokes` too — this is a sub-count, not an addition.
    public let putts: Int
    /// Where the tee shot ended up, if the player recorded it.
    public let teeShotLie: Lie?
    /// Where the approach shot ended up. Only meaningful on par 4 / par 5
    /// (par 3 has no separate approach — the tee shot is the approach).
    public let approachLie: Lie?
    /// Manually-entered penalty strokes (player ticks "+1" for an
    /// unplayable, lateral drop, etc.).
    public let penaltyStrokes: Int
    /// Per-hole count of shots that finished out-of-bounds. v1 capped
    /// this at 2 (tee + approach). v2 keeps it as an open count so a hole
    /// can record more than two OBs if needed.
    public let outOfBoundsCount: Int
    /// Per-hole count of shots that finished in a water hazard / penalty
    /// area. Same shape rationale as `outOfBoundsCount`.
    public let hazardCount: Int
    /// Manual override flag. If the player ticked "I scrambled here" but
    /// the auto-derivation (missed GIR + 1 putt + ≤ par) doesn't fire
    /// (e.g. they two-putted from the fringe), this lets `upAndDown`
    /// still return true.
    public let upAndDownSuccess: Bool
    /// Manual override flag for sand save. Same role as `upAndDownSuccess`.
    public let sandSaveSuccess: Bool

    public init(
        par: Int,
        strokes: Int,
        putts: Int,
        teeShotLie: Lie? = nil,
        approachLie: Lie? = nil,
        penaltyStrokes: Int = 0,
        outOfBoundsCount: Int = 0,
        hazardCount: Int = 0,
        upAndDownSuccess: Bool = false,
        sandSaveSuccess: Bool = false
    ) {
        self.par = par
        self.strokes = strokes
        self.putts = putts
        self.teeShotLie = teeShotLie
        self.approachLie = approachLie
        self.penaltyStrokes = penaltyStrokes
        self.outOfBoundsCount = outOfBoundsCount
        self.hazardCount = hazardCount
        self.upAndDownSuccess = upAndDownSuccess
        self.sandSaveSuccess = sandSaveSuccess
    }

    // MARK: - Derived

    /// Number of bunker shots recorded. 0, 1, or 2 in normal play
    /// (tee + approach can each be in sand). Drives `sandSave`.
    public var bunkerCount: Int {
        (teeShotLie?.isBunker == true ? 1 : 0)
            + (approachLie?.isBunker == true ? 1 : 0)
    }

    /// Green in regulation. The classic golf-stat rule:
    /// - Par 3: tee shot finishes on the green.
    /// - Par 4 / par 5: tee shot drives the green, or approach finishes there.
    /// - **Plus** `strokes − putts ≤ par − 2` so a hole reached the green
    ///   with one stroke to spare for two putts.
    ///
    /// The second clause matters when v1's UI lets the player tick
    /// "approach on green" but they actually scrambled there (tee → bunker
    /// → green isn't a GIR even though the approach landed on green).
    /// Returns `false` if `strokes` or `putts` is zero (hole not yet
    /// played) — same defensive guard as v1.
    public var greenInRegulation: Bool {
        guard strokes > 0, putts > 0, putts <= strokes else { return false }
        let greenLanding = teeShotLie == .green ? teeShotLie : (par == 3 ? teeShotLie : approachLie)
        return greenLanding == .green && (strokes - putts) <= par - 2
    }

    /// Fairway in regulation. Par 4+ only (a par 3's tee shot targets
    /// the green, not a fairway). True iff the tee shot finished on the
    /// fairway.
    public var fairwayInRegulation: Bool {
        par >= 4 && teeShotLie == .fairway
    }

    /// Three-putt (or worse). Pure putt count; doesn't care about the
    /// rest of the hole.
    public var threePutt: Bool {
        putts >= 3
    }

    /// Up-and-down made. True if **either**:
    /// - the player manually ticked `upAndDownSuccess`, OR
    /// - the auto-rule fires: GIR was missed, exactly one putt was taken,
    ///   and the hole was completed at or under par.
    ///
    /// The manual override exists because the auto-rule misses some real
    /// up-and-downs (e.g. a chip-in counts: 0 putts; v1's auto-rule
    /// requires `putts == 1` so the player has to tick the box).
    public var upAndDown: Bool {
        if upAndDownSuccess { return true }
        return !greenInRegulation && putts == 1 && strokes <= par
    }

    /// Sand save made. True if **either**:
    /// - the player manually ticked `sandSaveSuccess`, OR
    /// - at least one bunker shot was recorded, exactly one putt was
    ///   taken, and the hole was completed at or under par.
    public var sandSave: Bool {
        if sandSaveSuccess { return true }
        return bunkerCount > 0 && putts == 1 && strokes <= par
    }

    /// Effective penalty strokes for the hole.
    ///
    /// Formula: `max(penaltyStrokes, outOfBoundsCount + hazardCount)`.
    ///
    /// The max-not-sum is deliberate: v1's UI lets the player either tick
    /// individual OB / hazard shots **or** type a manual penalty total;
    /// taking the max prevents double-counting when both are entered. We
    /// preserve that v1 contract verbatim — see plan invariant #3.
    ///
    /// Note this **under-weighs** OB (a real OB costs +2: stroke + distance)
    /// but matches v1's stored value exactly. A future refinement is
    /// noted in the plan's "open items".
    public var effectivePenaltyStrokes: Int {
        max(penaltyStrokes, outOfBoundsCount + hazardCount)
    }
}

// MARK: - Lie helpers

public extension Lie {
    /// True if this lie is one of the four bunker variants. Used by
    /// `HoleStat.bunkerCount` (and any UI categorisation that wants to
    /// group "in the sand").
    var isBunker: Bool {
        switch self {
        case .bunkerLeft, .bunkerRight, .bunkerShort, .bunkerLong:
            true
        case .fairway, .roughLeft, .roughRight,
             .recoveryLeft, .recoveryRight, .recoveryShort, .recoveryLong,
             .green:
            false
        }
    }
}
