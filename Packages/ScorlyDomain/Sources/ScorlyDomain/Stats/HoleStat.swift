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

    /// OB shots that finished left of the target line.
    public let outOfBoundsLeft: Int
    /// OB shots that finished right of the target line.
    public let outOfBoundsRight: Int
    /// OB shots that finished long (past the green / fairway target).
    public let outOfBoundsLong: Int
    /// OB shots that finished short (well short of the target).
    public let outOfBoundsShort: Int
    /// Water / penalty shots that finished left of the target line.
    public let hazardLeft: Int
    /// Water / penalty shots that finished right of the target line.
    public let hazardRight: Int
    /// Water / penalty shots that finished long.
    public let hazardLong: Int
    /// Water / penalty shots that finished short.
    public let hazardShort: Int
    /// Manual override flag. If the player ticked "I scrambled here" but
    /// the auto-derivation (missed GIR + 1 putt + ≤ par) doesn't fire
    /// (e.g. they two-putted from the fringe), this lets `upAndDown`
    /// still return true.
    public let upAndDownSuccess: Bool
    /// Manual override flag for sand save. Same role as `upAndDownSuccess`.
    public let sandSaveSuccess: Bool
    /// Distance the tee shot travelled, yards. Optional — only some
    /// rounds (v2 round play) record this. Needed by `SGCalculator`.
    public let teeShotDistance: Int?
    /// Distance remaining when the approach shot was taken, yards.
    /// Unused on par 3 (tee shot is the approach). Optional for the
    /// same reason as `teeShotDistance`.
    public let approachDistance: Int?
    /// Putt distances in feet, ordered by stroke (first putt → last).
    /// Optional — populated only when the player logged distances on
    /// the green during the round.
    public let puttDistances: [Int]?
    /// Club used for the tee shot, free-form string (e.g. "Driver",
    /// "5 iron"). Optional — only populated when the player logged it.
    public let teeClub: String?
    /// Club used for the approach shot, free-form string. Unused on
    /// par 3 (the tee shot is the approach). Optional.
    public let approachClub: String?
    /// Pin position string (e.g. "Front", "Middle", "Back"). Optional.
    public let pinPosition: String?

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
        sandSaveSuccess: Bool = false,
        teeShotDistance: Int? = nil,
        approachDistance: Int? = nil,
        puttDistances: [Int]? = nil,
        teeClub: String? = nil,
        approachClub: String? = nil,
        pinPosition: String? = nil,
        outOfBoundsLeft: Int = 0,
        outOfBoundsRight: Int = 0,
        outOfBoundsLong: Int = 0,
        outOfBoundsShort: Int = 0,
        hazardLeft: Int = 0,
        hazardRight: Int = 0,
        hazardLong: Int = 0,
        hazardShort: Int = 0
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
        self.teeShotDistance = teeShotDistance
        self.approachDistance = approachDistance
        self.puttDistances = puttDistances
        self.teeClub = teeClub
        self.approachClub = approachClub
        self.pinPosition = pinPosition
        self.outOfBoundsLeft = outOfBoundsLeft
        self.outOfBoundsRight = outOfBoundsRight
        self.outOfBoundsLong = outOfBoundsLong
        self.outOfBoundsShort = outOfBoundsShort
        self.hazardLeft = hazardLeft
        self.hazardRight = hazardRight
        self.hazardLong = hazardLong
        self.hazardShort = hazardShort
    }

    // MARK: - Codable

    // Forwards-compat decode: the eight directional hazard fields were
    // added after launch. Older serialized HoleStat blobs (test fixtures,
    // any in-memory snapshots) won't include them; decodeIfPresent
    // defaults each to 0 so old payloads continue to round-trip.

    enum CodingKeys: String, CodingKey {
        case par, strokes, putts, teeShotLie, approachLie, penaltyStrokes,
             outOfBoundsCount, hazardCount, upAndDownSuccess, sandSaveSuccess,
             teeShotDistance, approachDistance, puttDistances, teeClub,
             approachClub, pinPosition,
             outOfBoundsLeft, outOfBoundsRight, outOfBoundsLong, outOfBoundsShort,
             hazardLeft, hazardRight, hazardLong, hazardShort
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        par = try container.decode(Int.self, forKey: .par)
        strokes = try container.decode(Int.self, forKey: .strokes)
        putts = try container.decode(Int.self, forKey: .putts)
        teeShotLie = try container.decodeIfPresent(Lie.self, forKey: .teeShotLie)
        approachLie = try container.decodeIfPresent(Lie.self, forKey: .approachLie)
        penaltyStrokes = try container.decode(Int.self, forKey: .penaltyStrokes)
        outOfBoundsCount = try container.decode(Int.self, forKey: .outOfBoundsCount)
        hazardCount = try container.decode(Int.self, forKey: .hazardCount)
        upAndDownSuccess = try container.decode(Bool.self, forKey: .upAndDownSuccess)
        sandSaveSuccess = try container.decode(Bool.self, forKey: .sandSaveSuccess)
        teeShotDistance = try container.decodeIfPresent(Int.self, forKey: .teeShotDistance)
        approachDistance = try container.decodeIfPresent(Int.self, forKey: .approachDistance)
        puttDistances = try container.decodeIfPresent([Int].self, forKey: .puttDistances)
        teeClub = try container.decodeIfPresent(String.self, forKey: .teeClub)
        approachClub = try container.decodeIfPresent(String.self, forKey: .approachClub)
        pinPosition = try container.decodeIfPresent(String.self, forKey: .pinPosition)
        outOfBoundsLeft = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsLeft) ?? 0
        outOfBoundsRight = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsRight) ?? 0
        outOfBoundsLong = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsLong) ?? 0
        outOfBoundsShort = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsShort) ?? 0
        hazardLeft = try container.decodeIfPresent(Int.self, forKey: .hazardLeft) ?? 0
        hazardRight = try container.decodeIfPresent(Int.self, forKey: .hazardRight) ?? 0
        hazardLong = try container.decodeIfPresent(Int.self, forKey: .hazardLong) ?? 0
        hazardShort = try container.decodeIfPresent(Int.self, forKey: .hazardShort) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(par, forKey: .par)
        try container.encode(strokes, forKey: .strokes)
        try container.encode(putts, forKey: .putts)
        try container.encodeIfPresent(teeShotLie, forKey: .teeShotLie)
        try container.encodeIfPresent(approachLie, forKey: .approachLie)
        try container.encode(penaltyStrokes, forKey: .penaltyStrokes)
        try container.encode(outOfBoundsCount, forKey: .outOfBoundsCount)
        try container.encode(hazardCount, forKey: .hazardCount)
        try container.encode(upAndDownSuccess, forKey: .upAndDownSuccess)
        try container.encode(sandSaveSuccess, forKey: .sandSaveSuccess)
        try container.encodeIfPresent(teeShotDistance, forKey: .teeShotDistance)
        try container.encodeIfPresent(approachDistance, forKey: .approachDistance)
        try container.encodeIfPresent(puttDistances, forKey: .puttDistances)
        try container.encodeIfPresent(teeClub, forKey: .teeClub)
        try container.encodeIfPresent(approachClub, forKey: .approachClub)
        try container.encodeIfPresent(pinPosition, forKey: .pinPosition)
        try container.encode(outOfBoundsLeft, forKey: .outOfBoundsLeft)
        try container.encode(outOfBoundsRight, forKey: .outOfBoundsRight)
        try container.encode(outOfBoundsLong, forKey: .outOfBoundsLong)
        try container.encode(outOfBoundsShort, forKey: .outOfBoundsShort)
        try container.encode(hazardLeft, forKey: .hazardLeft)
        try container.encode(hazardRight, forKey: .hazardRight)
        try container.encode(hazardLong, forKey: .hazardLong)
        try container.encode(hazardShort, forKey: .hazardShort)
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

    /// Whether this hole counts as a fairway-in-regulation *opportunity*
    /// (the denominator for FIR rate). Par 4 and par 5 always; par 3
    /// never.
    public var fairwayOpportunity: Bool {
        par >= 4
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
