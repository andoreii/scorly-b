import Foundation
import Observation
import ScorlyDomain

/// One hole's worth of in-progress input. Differs from `HoleStat`
/// (the immutable, fully-typed completed-round shape in
/// `ScorlyDomain`) in two ways:
///
/// 1. `strokes` is nullable — `nil` means "not logged yet" so the
///    Play screen can render the par as a placeholder.
/// 2. `teeShot` / `approach` are raw `LieKeypad` strings ("Fairway",
///    "Miss Left", "OB Long"). The `teeShotModifier` / `approachModifier`
///    fields hold an optional "Bunker" or "Water" companion. Both
///    are decoded into a typed `HoleStat` only when derivation runs.
public struct HoleEntry: Equatable, Sendable {
    public var strokes: Int?
    public var putts: Int
    public var puttDistances: [Int?]
    public var teeShot: String?
    public var teeShotModifier: String?
    public var teeClub: String?
    public var teeShotDistance: Int?
    public var approach: String?
    public var approachModifier: String?
    public var approachClub: String?
    public var approachDistance: Int?
    public var pinPosition: String?
    public var penaltyStrokes: Int
    public var upAndDownOverride: Bool?
    public var sandSaveOverride: Bool?

    public init(
        strokes: Int? = nil,
        putts: Int = 0,
        puttDistances: [Int?] = [],
        teeShot: String? = nil,
        teeShotModifier: String? = nil,
        teeClub: String? = nil,
        teeShotDistance: Int? = nil,
        approach: String? = nil,
        approachModifier: String? = nil,
        approachClub: String? = nil,
        approachDistance: Int? = nil,
        pinPosition: String? = nil,
        penaltyStrokes: Int = 0,
        upAndDownOverride: Bool? = nil,
        sandSaveOverride: Bool? = nil
    ) {
        self.strokes = strokes
        self.putts = putts
        self.puttDistances = puttDistances
        self.teeShot = teeShot
        self.teeShotModifier = teeShotModifier
        self.teeClub = teeClub
        self.teeShotDistance = teeShotDistance
        self.approach = approach
        self.approachModifier = approachModifier
        self.approachClub = approachClub
        self.approachDistance = approachDistance
        self.pinPosition = pinPosition
        self.penaltyStrokes = penaltyStrokes
        self.upAndDownOverride = upAndDownOverride
        self.sandSaveOverride = sandSaveOverride
    }
}

/// Live-round state — owns the slice of holes being played, the
/// per-hole entries, the cursor index, and which shot block is
/// currently expanded.
///
/// One instance is created when the player taps "Tee off" in
/// SetupView and discarded on exit from the round flow.
@MainActor
@Observable
public final class RoundPlayState {
    public let course: Course
    public let tee: Tee?
    public let holes: [Hole]
    public var entries: [HoleEntry]
    public var holeIdx: Int
    public var openShot: OpenShot
    public var scorecardOpen: Bool
    public var penaltySheetOpen: Bool

    public enum OpenShot: Equatable {
        case none
        case tee
        case approach
        case putts
    }

    public init(course: Course, teeId: UUID?, holesPlayed: HolesPlayed) {
        self.course = course
        self.tee = course.tees.first(where: { $0.id == teeId }) ?? course.tees.first

        let sortedHoles = course.holes.sorted { $0.number < $1.number }
        let slice: [Hole]
        switch holesPlayed {
        case .front9:
            slice = Array(sortedHoles.prefix(9))
        case .back9:
            slice = Array(sortedHoles.dropFirst(9).prefix(9))
        case .eighteen:
            slice = sortedHoles
        }
        self.holes = slice
        self.entries = Array(repeating: HoleEntry(), count: slice.count)
        self.holeIdx = 0
        self.openShot = .none
        self.scorecardOpen = false
        self.penaltySheetOpen = false
    }

    /// Strokes summed across logged holes only.
    public var totalStrokes: Int {
        entries.reduce(0) { $0 + ($1.strokes ?? 0) }
    }

    /// Par summed across logged holes only (matches the design's
    /// "+ vs PAR" running tally — un-logged holes don't count).
    public var playedPar: Int {
        zip(holes, entries).reduce(0) { acc, pair in
            pair.1.strokes != nil ? acc + pair.0.par : acc
        }
    }

    public var vsPar: Int { totalStrokes - playedPar }

    public var filledCount: Int {
        entries.reduce(0) { $0 + ($1.strokes == nil ? 0 : 1) }
    }

    public var currentHole: Hole { holes[holeIdx] }
    public var currentEntry: HoleEntry {
        get { entries[holeIdx] }
        set { entries[holeIdx] = newValue }
    }

    public var teeYardageForCurrentHole: Int? {
        let number = currentHole.number
        return tee?.teeHoles.first(where: { $0.holeNumber == number })?.yardage
    }

    public func move(delta: Int) {
        if delta > 0 {
            commitParIfNil(at: holeIdx)
        }
        holeIdx = max(0, min(holes.count - 1, holeIdx + delta))
        openShot = .none
    }

    /// If the hole at `index` was never logged, treat it as a par. Used
    /// when the player advances past a hole or taps FINISH so the
    /// totals, the `+vs PAR` counter, and the Supabase payload all
    /// reflect "untouched == par" instead of zero.
    public func commitParIfNil(at index: Int) {
        guard index >= 0, index < entries.count else { return }
        if entries[index].strokes == nil {
            entries[index].strokes = holes[index].par
        }
    }

    public func jump(to index: Int) {
        holeIdx = max(0, min(holes.count - 1, index))
        openShot = .none
    }

    /// Build a `HoleStat` snapshot of the current entry, used to
    /// drive the FIR / GIR / 3-putt / etc. chips. Falls back to
    /// `hole.par` when the stepper hasn't been touched so the metrics
    /// can react to lie / putt changes even on a default-par hole.
    public func derivedStat(for index: Int) -> HoleStat {
        let entry = entries[index]
        let hole = holes[index]
        let strokes = entry.strokes ?? hole.par
        let teeDecoded = Self.decodeLie(entry.teeShot, modifier: entry.teeShotModifier, target: .fairway)
        let approachDecoded = Self.decodeLie(entry.approach, modifier: entry.approachModifier, target: .green)
        return HoleStat(
            par: hole.par,
            strokes: strokes,
            putts: entry.putts,
            teeShotLie: teeDecoded.lie,
            approachLie: approachDecoded.lie,
            penaltyStrokes: entry.penaltyStrokes,
            outOfBoundsCount: teeDecoded.ob + approachDecoded.ob,
            hazardCount: teeDecoded.hazard + approachDecoded.hazard,
            upAndDownSuccess: entry.upAndDownOverride ?? false,
            sandSaveSuccess: entry.sandSaveOverride ?? false
        )
    }

    // MARK: - Lie decoding

    private struct DecodedLie {
        let lie: Lie?
        let ob: Int
        let hazard: Int
    }

    /// Maps a `LieKeypad` raw direction + optional modifier into the
    /// closest `Lie` enum + out-of-bounds / hazard counters. The keypad
    /// emits direction strings ("Fairway", "Green", "Miss …", "OB …")
    /// alongside an optional "Bunker" / "Water" modifier; this collapses
    /// them into the `Lie` rawValues the domain expects, routing OB /
    /// hazard outcomes to counters where they have no playable lie.
    private static func decodeLie(
        _ raw: String?,
        modifier: String?,
        target: Lie
    ) -> DecodedLie {
        guard let raw else { return DecodedLie(lie: nil, ob: 0, hazard: 0) }
        if raw == "Fairway" { return DecodedLie(lie: .fairway, ob: 0, hazard: 0) }
        if raw == "Green" { return DecodedLie(lie: .green, ob: 0, hazard: 0) }
        // Legacy single-string entries (back-compat for any data that
        // pre-dated the modifier split).
        if raw == "Bunker" { return DecodedLie(lie: .bunkerLeft, ob: 0, hazard: 0) }
        if raw == "Water Hazard" { return DecodedLie(lie: nil, ob: 0, hazard: 1) }

        if raw.hasPrefix("OB ") {
            // Water modifier on an OB direction reclassifies the outcome
            // as a hazard (the ball is findable in water, not lost OB).
            if modifier == "Water" {
                return DecodedLie(lie: nil, ob: 0, hazard: 1)
            }
            return DecodedLie(lie: nil, ob: 1, hazard: 0)
        }

        if raw.hasPrefix("Miss ") {
            let direction = String(raw.dropFirst(5))
            let isApproach = target == .green
            if modifier == "Bunker" {
                let bunker: Lie
                switch direction {
                case "Left":  bunker = .bunkerLeft
                case "Right": bunker = .bunkerRight
                case "Long":  bunker = .bunkerLong
                case "Short": bunker = .bunkerShort
                default:      bunker = .bunkerLeft
                }
                return DecodedLie(lie: bunker, ob: 0, hazard: 0)
            }
            let lie: Lie
            switch (direction, isApproach) {
            case ("Left", false): lie = .roughLeft
            case ("Right", false): lie = .roughRight
            case ("Long", false): lie = .roughLeft
            case ("Short", false): lie = .roughRight
            case ("Left", true): lie = .recoveryLeft
            case ("Right", true): lie = .recoveryRight
            case ("Long", true): lie = .recoveryLong
            case ("Short", true): lie = .recoveryShort
            default: lie = isApproach ? .recoveryLeft : .roughLeft
            }
            return DecodedLie(lie: lie, ob: 0, hazard: 0)
        }
        return DecodedLie(lie: nil, ob: 0, hazard: 0)
    }
}

/// Standard golf-bag club order, matching the React design source.
/// Wedges are labelled by loft (50°/54°/58°) rather than GW/SW/LW.
public let BrutalistClubs: [String] = [
    "Driver", "3-Wood", "5-Wood", "Hybrid",
    "3i", "4i", "5i", "6i", "7i", "8i", "9i",
    "PW", "50", "54", "58", "Putter",
]

/// Default yardages used to auto-set the distance wheel when the user
/// picks a club in the tee-shot or approach editor. Putter is omitted
/// so picking it never overwrites a manually-dialed distance.
public let BrutalistClubDistances: [String: Int] = [
    "Driver": 250,
    "3-Wood": 225,
    "5-Wood": 210,
    "Hybrid": 200,
    "3i": 195,
    "4i": 185,
    "5i": 175,
    "6i": 165,
    "7i": 150,
    "8i": 140,
    "9i": 130,
    "PW": 115,
    "50": 100,
    "54": 85,
    "58": 70,
]
