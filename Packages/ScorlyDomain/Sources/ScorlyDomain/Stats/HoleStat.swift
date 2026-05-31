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
///    *playable* lies), and OB / hazard outcomes flow into the
///    `penaltyEvents` list.
///
/// 2. v1 derived `bunkerCount` from string prefixes; v2 derives it from
///    the `Lie` enum via `Lie.isBunker`. Same semantics, type-safe.
///
/// 3. v2 collapses the original ten OB / hazard counter columns
///    (`outOfBoundsLeft`, `hazardLong`, etc.) into a single
///    `penaltyEvents: [PenaltyEvent]` list. Per-direction and total
///    counts are exposed as computed properties so existing
///    derivations (GIR, sand save, effective penalty strokes) keep
///    working without churn at every call site.
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
    /// Every stroke that finished in trouble, ordered by stroke. One
    /// entry per OB / hazard event; direction is optional (nil = the
    /// user didn't pick one, as in legacy rounds).
    public let penaltyEvents: [PenaltyEvent]
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
    /// Distance the approach finished from the pin, in yards. Only set
    /// when `approachLie` is non-green (it's how we anchor the chip's
    /// start). Nil = SG calculator falls back to a lie-based default.
    public let approachLandingDistance: Int?
    /// One entry per around-the-green shot, ordered by stroke. Length
    /// should match the inferred ARG count (`strokes − putts − 2` on
    /// par 4/5; `strokes − putts − 1` on par 3 off-green). Nil = SG
    /// calculator uses lie-based defaults for every chip on this hole.
    public let argShots: [ARGShot]?
    /// Par-5 only: lie where the layup landed. Presence flips the
    /// SG reconstruction to a three-shot pre-green chain.
    public let layupLie: Lie?
    /// Par-5 only: distance from pin after the layup, in yards.
    public let layupDistance: Int?

    public init(
        par: Int,
        strokes: Int,
        putts: Int,
        teeShotLie: Lie? = nil,
        approachLie: Lie? = nil,
        penaltyStrokes: Int = 0,
        penaltyEvents: [PenaltyEvent] = [],
        upAndDownSuccess: Bool = false,
        sandSaveSuccess: Bool = false,
        teeShotDistance: Int? = nil,
        approachDistance: Int? = nil,
        puttDistances: [Int]? = nil,
        teeClub: String? = nil,
        approachClub: String? = nil,
        pinPosition: String? = nil,
        approachLandingDistance: Int? = nil,
        argShots: [ARGShot]? = nil,
        layupLie: Lie? = nil,
        layupDistance: Int? = nil
    ) {
        self.par = par
        self.strokes = strokes
        self.putts = putts
        self.teeShotLie = teeShotLie
        self.approachLie = approachLie
        self.penaltyStrokes = penaltyStrokes
        self.penaltyEvents = penaltyEvents
        self.upAndDownSuccess = upAndDownSuccess
        self.sandSaveSuccess = sandSaveSuccess
        self.teeShotDistance = teeShotDistance
        self.approachDistance = approachDistance
        self.puttDistances = puttDistances
        self.teeClub = teeClub
        self.approachClub = approachClub
        self.pinPosition = pinPosition
        self.approachLandingDistance = approachLandingDistance
        self.argShots = argShots
        self.layupLie = layupLie
        self.layupDistance = layupDistance
    }

    // MARK: - Codable

    // Forwards-compat decode: older serialized blobs (test fixtures, any
    // in-memory snapshots) carry the v1 counter columns
    // (`outOfBoundsCount`, `outOfBoundsLeft`, etc.) instead of the
    // `penaltyEvents` list. The decoder reads either shape and folds
    // the legacy counters into the events list at load time.

    enum CodingKeys: String, CodingKey {
        case par, strokes, putts, teeShotLie, approachLie, penaltyStrokes,
             penaltyEvents,
             upAndDownSuccess, sandSaveSuccess,
             teeShotDistance, approachDistance, puttDistances, teeClub,
             approachClub, pinPosition,
             approachLandingDistance, argShots, layupLie, layupDistance,
             // Legacy decode-only keys — never written by new encoders.
             outOfBoundsCount, hazardCount,
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
        upAndDownSuccess = try container.decode(Bool.self, forKey: .upAndDownSuccess)
        sandSaveSuccess = try container.decode(Bool.self, forKey: .sandSaveSuccess)
        teeShotDistance = try container.decodeIfPresent(Int.self, forKey: .teeShotDistance)
        approachDistance = try container.decodeIfPresent(Int.self, forKey: .approachDistance)
        puttDistances = try container.decodeIfPresent([Int].self, forKey: .puttDistances)
        teeClub = try container.decodeIfPresent(String.self, forKey: .teeClub)
        approachClub = try container.decodeIfPresent(String.self, forKey: .approachClub)
        pinPosition = try container.decodeIfPresent(String.self, forKey: .pinPosition)
        approachLandingDistance = try container.decodeIfPresent(Int.self, forKey: .approachLandingDistance)
        argShots = try container.decodeIfPresent([ARGShot].self, forKey: .argShots)
        layupLie = try container.decodeIfPresent(Lie.self, forKey: .layupLie)
        layupDistance = try container.decodeIfPresent(Int.self, forKey: .layupDistance)

        if let events = try container.decodeIfPresent([PenaltyEvent].self, forKey: .penaltyEvents) {
            penaltyEvents = events
        } else {
            // Legacy: build events from the old counter columns. The
            // directional counts produce events with `direction` set;
            // any residual count beyond the sum of directions yields
            // direction-nil events (the v1 "OB recorded but not
            // localized" case).
            let obLeft = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsLeft) ?? 0
            let obRight = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsRight) ?? 0
            let obLong = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsLong) ?? 0
            let obShort = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsShort) ?? 0
            let obTotal = try container.decodeIfPresent(Int.self, forKey: .outOfBoundsCount) ?? 0
            let hzLeft = try container.decodeIfPresent(Int.self, forKey: .hazardLeft) ?? 0
            let hzRight = try container.decodeIfPresent(Int.self, forKey: .hazardRight) ?? 0
            let hzLong = try container.decodeIfPresent(Int.self, forKey: .hazardLong) ?? 0
            let hzShort = try container.decodeIfPresent(Int.self, forKey: .hazardShort) ?? 0
            let hzTotal = try container.decodeIfPresent(Int.self, forKey: .hazardCount) ?? 0
            penaltyEvents = Self.eventsFromLegacy(
                obTotal: obTotal,
                obLeft: obLeft,
                obRight: obRight,
                obLong: obLong,
                obShort: obShort,
                hzTotal: hzTotal,
                hzLeft: hzLeft,
                hzRight: hzRight,
                hzLong: hzLong,
                hzShort: hzShort
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(par, forKey: .par)
        try container.encode(strokes, forKey: .strokes)
        try container.encode(putts, forKey: .putts)
        try container.encodeIfPresent(teeShotLie, forKey: .teeShotLie)
        try container.encodeIfPresent(approachLie, forKey: .approachLie)
        try container.encode(penaltyStrokes, forKey: .penaltyStrokes)
        try container.encode(penaltyEvents, forKey: .penaltyEvents)
        try container.encode(upAndDownSuccess, forKey: .upAndDownSuccess)
        try container.encode(sandSaveSuccess, forKey: .sandSaveSuccess)
        try container.encodeIfPresent(teeShotDistance, forKey: .teeShotDistance)
        try container.encodeIfPresent(approachDistance, forKey: .approachDistance)
        try container.encodeIfPresent(puttDistances, forKey: .puttDistances)
        try container.encodeIfPresent(teeClub, forKey: .teeClub)
        try container.encodeIfPresent(approachClub, forKey: .approachClub)
        try container.encodeIfPresent(pinPosition, forKey: .pinPosition)
        try container.encodeIfPresent(approachLandingDistance, forKey: .approachLandingDistance)
        try container.encodeIfPresent(argShots, forKey: .argShots)
        try container.encodeIfPresent(layupLie, forKey: .layupLie)
        try container.encodeIfPresent(layupDistance, forKey: .layupDistance)
    }

    /// Folds the legacy 10-column counter shape into a `[PenaltyEvent]`
    /// list. Public so the data layer's SQL/SwiftData migration can use
    /// the same backfill logic the in-memory decoder applies.
    public static func eventsFromLegacy( // swiftlint:disable:this function_parameter_count

        obTotal: Int,
        obLeft: Int,
        obRight: Int,
        obLong: Int,
        obShort: Int,
        hzTotal: Int,
        hzLeft: Int,
        hzRight: Int,
        hzLong: Int,
        hzShort: Int
    ) -> [PenaltyEvent] {
        var events: [PenaltyEvent] = []
        events.reserveCapacity(max(obTotal, obLeft + obRight + obLong + obShort)
            + max(hzTotal, hzLeft + hzRight + hzLong + hzShort))

        func append(kind: PenaltyKind, direction: PenaltyDirection, count: Int) {
            for _ in 0..<max(0, count) {
                events.append(PenaltyEvent(kind: kind, direction: direction))
            }
        }
        append(kind: .outOfBounds, direction: .left, count: obLeft)
        append(kind: .outOfBounds, direction: .right, count: obRight)
        append(kind: .outOfBounds, direction: .long, count: obLong)
        append(kind: .outOfBounds, direction: .short, count: obShort)
        let obDirectionalSum = obLeft + obRight + obLong + obShort
        if obTotal > obDirectionalSum {
            for _ in 0..<(obTotal - obDirectionalSum) {
                events.append(PenaltyEvent(kind: .outOfBounds, direction: nil))
            }
        }
        append(kind: .hazard, direction: .left, count: hzLeft)
        append(kind: .hazard, direction: .right, count: hzRight)
        append(kind: .hazard, direction: .long, count: hzLong)
        append(kind: .hazard, direction: .short, count: hzShort)
        let hzDirectionalSum = hzLeft + hzRight + hzLong + hzShort
        if hzTotal > hzDirectionalSum {
            for _ in 0..<(hzTotal - hzDirectionalSum) {
                events.append(PenaltyEvent(kind: .hazard, direction: nil))
            }
        }
        return events
    }

    // MARK: - Penalty accessors

    /// Count of out-of-bounds events. Sums the events list; replaces
    /// the old stored `outOfBoundsCount` column.
    public var outOfBoundsCount: Int {
        penaltyEvents.lazy.filter { $0.kind == .outOfBounds }.count
    }

    /// Count of water / penalty-area events.
    public var hazardCount: Int {
        penaltyEvents.lazy.filter { $0.kind == .hazard }.count
    }

    /// Per-direction OB counts. Backwards-compat accessors for code
    /// that previously read the dedicated columns.
    public var outOfBoundsLeft: Int {
        count(kind: .outOfBounds, direction: .left)
    }

    public var outOfBoundsRight: Int {
        count(kind: .outOfBounds, direction: .right)
    }

    public var outOfBoundsLong: Int {
        count(kind: .outOfBounds, direction: .long)
    }

    public var outOfBoundsShort: Int {
        count(kind: .outOfBounds, direction: .short)
    }

    public var hazardLeft: Int {
        count(kind: .hazard, direction: .left)
    }

    public var hazardRight: Int {
        count(kind: .hazard, direction: .right)
    }

    public var hazardLong: Int {
        count(kind: .hazard, direction: .long)
    }

    public var hazardShort: Int {
        count(kind: .hazard, direction: .short)
    }

    private func count(kind: PenaltyKind, direction: PenaltyDirection) -> Int {
        penaltyEvents.lazy.filter { $0.kind == kind && $0.direction == direction }.count
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
