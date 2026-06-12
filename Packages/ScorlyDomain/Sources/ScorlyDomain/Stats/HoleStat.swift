import Foundation

/// One hole's worth of recorded play, used to derive per-hole stats (GIR, FIR, 3-putt, etc).
/// OB/hazard outcomes live in `penaltyEvents`; computed properties below expose the old
/// per-direction shape for existing call sites.
public struct HoleStat: Sendable, Equatable, Codable {
    public let par: Int
    /// Total strokes taken on the hole, including putts and any penalty strokes.
    public let strokes: Int
    /// Sub-count of `strokes` taken from the green, not an addition.
    public let putts: Int
    /// Where the tee shot ended up, if the player recorded it.
    public let teeShotLie: Lie?
    /// Where the approach shot ended up. Only meaningful on par 4 / par 5.
    public let approachLie: Lie?
    /// Manually-entered penalty strokes (player ticks "+1" for an unplayable, drop, etc.).
    public let penaltyStrokes: Int
    /// Every stroke that finished in trouble, ordered by stroke.
    public let penaltyEvents: [PenaltyEvent]
    /// Manual override so a real up-and-down counts even if the auto-rule
    /// (missed GIR + 1 putt + <= par) doesn't fire.
    public let upAndDownSuccess: Bool
    /// Manual override flag for sand save. Same role as `upAndDownSuccess`.
    public let sandSaveSuccess: Bool
    /// Distance the tee shot travelled, yards. Needed by `SGCalculator`.
    public let teeShotDistance: Int?
    /// Distance remaining when the approach shot was taken, yards. Unused on par 3.
    public let approachDistance: Int?
    /// Putt distances in feet, ordered first putt to last.
    public let puttDistances: [Int]?
    /// Club used for the tee shot, free-form string (e.g. "Driver", "5 iron").
    public let teeClub: String?
    /// Club used for the approach shot. Unused on par 3.
    public let approachClub: String?
    public let pinPosition: String?
    /// Distance the approach finished from the pin, in yards; nil falls back to a lie-based default.
    public let approachLandingDistance: Int?
    /// One entry per around-the-green shot, ordered by stroke. Nil means SG uses lie-based defaults.
    public let argShots: [ARGShot]?
    /// Par-5 only: lie where the layup landed. Presence flips SG to a three-shot pre-green chain.
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

    // Older blobs carry per-direction OB/hazard counters instead of `penaltyEvents`;
    // the decoder folds those into events.

    enum CodingKeys: String, CodingKey {
        case par, strokes, putts, teeShotLie, approachLie, penaltyStrokes,
             penaltyEvents,
             upAndDownSuccess, sandSaveSuccess,
             teeShotDistance, approachDistance, puttDistances, teeClub,
             approachClub, pinPosition,
             approachLandingDistance, argShots, layupLie, layupDistance,
             // Legacy decode-only keys, never written by new encoders.
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
            // Legacy: any count beyond the directional sum becomes a direction-nil event.
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

    /// Folds the legacy 10-column counter shape into a `[PenaltyEvent]` list.
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

    /// Count of out-of-bounds events.
    public var outOfBoundsCount: Int {
        penaltyEvents.lazy.filter { $0.kind == .outOfBounds }.count
    }

    /// Count of water / penalty-area events.
    public var hazardCount: Int {
        penaltyEvents.lazy.filter { $0.kind == .hazard }.count
    }

    /// Per-direction OB counts, for backwards-compat call sites.
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

    /// 0, 1, or 2: tee and/or approach can each be in sand. Drives `sandSave`.
    public var bunkerCount: Int {
        (teeShotLie?.isBunker == true ? 1 : 0)
            + (approachLie?.isBunker == true ? 1 : 0)
    }

    /// Ball on green in par minus 2 strokes, with enough strokes left for two putts.
    public var greenInRegulation: Bool {
        guard strokes > 0, putts > 0, putts <= strokes else { return false }
        let greenLanding = teeShotLie == .green ? teeShotLie : (par == 3 ? teeShotLie : approachLie)
        return greenLanding == .green && (strokes - putts) <= par - 2
    }

    /// Par 4+ only: tee shot finished on the fairway.
    public var fairwayInRegulation: Bool {
        par >= 4 && teeShotLie == .fairway
    }

    /// Denominator for FIR rate: par 4 and 5 only.
    public var fairwayOpportunity: Bool {
        par >= 4
    }

    public var threePutt: Bool {
        putts >= 3
    }

    /// Manually flagged, or GIR missed with exactly one putt at or under par
    /// (covers chip-ins the auto-rule can't see).
    public var upAndDown: Bool {
        if upAndDownSuccess { return true }
        return !greenInRegulation && putts == 1 && strokes <= par
    }

    /// Manually flagged, or a bunker shot plus one putt at or under par.
    public var sandSave: Bool {
        if sandSaveSuccess { return true }
        return bunkerCount > 0 && putts == 1 && strokes <= par
    }

    /// Max of the manual total and the OB/hazard event count, to avoid double-counting.
    /// Under-weighs OB (a real OB costs +2: stroke and distance).
    public var effectivePenaltyStrokes: Int {
        max(penaltyStrokes, outOfBoundsCount + hazardCount)
    }
}

// MARK: - Lie helpers

public extension Lie {
    /// True if this lie is one of the four bunker variants.
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
