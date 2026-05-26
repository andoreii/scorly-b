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
public struct HoleEntry: Equatable, Sendable, Codable {
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
    public private(set) var holes: [Hole]
    public private(set) var holesPlayed: HolesPlayed
    public let startedAt: Date
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
        tee = course.tees.first(where: { $0.id == teeId }) ?? course.tees.first
        self.holesPlayed = holesPlayed
        startedAt = Date()

        let slice = Self.sliceHoles(course: course, holesPlayed: holesPlayed)
        holes = slice
        entries = Array(repeating: HoleEntry(), count: slice.count)
        holeIdx = 0
        openShot = .none
        scorecardOpen = false
        penaltySheetOpen = false
    }

    /// Resume a paused round. Caller must pre-validate that the entry
    /// count matches the holes-played slice; mismatches fall back to a
    /// fresh entry array.
    public init(
        course: Course,
        teeId: UUID?,
        holesPlayed: HolesPlayed,
        entries: [HoleEntry],
        holeIdx: Int,
        startedAt: Date
    ) {
        self.course = course
        tee = course.tees.first(where: { $0.id == teeId }) ?? course.tees.first
        self.holesPlayed = holesPlayed
        self.startedAt = startedAt

        let slice = Self.sliceHoles(course: course, holesPlayed: holesPlayed)
        holes = slice
        let raw = entries.count == slice.count
            ? entries
            : Array(repeating: HoleEntry(), count: slice.count)
        self.entries = raw.map(Self.normalizeEntry)
        self.holeIdx = max(0, min(slice.count - 1, holeIdx))
        openShot = .none
        scorecardOpen = false
        penaltySheetOpen = false
    }

    /// Strip distance from any OB tee-shot entry. Guards against drafts
    /// saved before this invariant was enforced.
    private static func normalizeEntry(_ entry: HoleEntry) -> HoleEntry {
        guard entry.teeShot?.hasPrefix("OB ") == true, entry.teeShotDistance != nil else {
            return entry
        }
        var normalized = entry
        normalized.teeShotDistance = nil
        return normalized
    }

    /// Reslice the round to a different holes-played mode mid-play.
    /// Existing entries are remapped by hole number so any strokes the
    /// player already logged on holes that survive the transition are
    /// preserved. Holes that drop out of the new slice (e.g. switching
    /// from 18 → FRONT 9 erases holes 10–18) lose their entries. The
    /// cursor stays on the same hole when possible; otherwise it
    /// clamps to the first hole of the new slice.
    public func changeHolesPlayed(to newValue: HolesPlayed) {
        guard newValue != holesPlayed else { return }
        let newSlice = Self.sliceHoles(course: course, holesPlayed: newValue)
        let oldEntriesByNumber = Dictionary(
            uniqueKeysWithValues: zip(holes.map(\.number), entries)
        )
        var newEntries = Array(repeating: HoleEntry(), count: newSlice.count)
        for (idx, hole) in newSlice.enumerated() {
            if let preserved = oldEntriesByNumber[hole.number] {
                newEntries[idx] = preserved
            }
        }
        let currentHoleNumber = holes.indices.contains(holeIdx) ? holes[holeIdx].number : nil
        let mappedIdx = currentHoleNumber
            .flatMap { num in newSlice.firstIndex { $0.number == num } } ?? 0
        holes = newSlice
        entries = newEntries
        holesPlayed = newValue
        holeIdx = mappedIdx
        openShot = .none
    }

    private static func sliceHoles(course: Course, holesPlayed: HolesPlayed) -> [Hole] {
        let sortedHoles = course.holes.sorted { $0.number < $1.number }
        switch holesPlayed {
        case .front9:
            return Array(sortedHoles.prefix(9))
        case .back9:
            return Array(sortedHoles.dropFirst(9).prefix(9))
        case .eighteen:
            return sortedHoles
        }
    }

    /// HoleStat snapshots for every hole the user has actually logged
    /// (`entry.strokes != nil`). Reuses `derivedStat(for:)` so live and
    /// sign-and-file values agree exactly (including the par-3 GIR seam).
    public var loggedHoleStats: [HoleStat] {
        entries.indices.compactMap { idx in
            entries[idx].strokes != nil ? derivedStat(for: idx) : nil
        }
    }

    /// Greens-in-regulation among logged holes. Both `made` and `of`
    /// come from the same logged-only pool so unplayed holes never
    /// dilute the percentage.
    public var liveGIR: (made: Int, of: Int) {
        let logged = loggedHoleStats
        return (logged.filter(\.greenInRegulation).count, logged.count)
    }

    /// Fairways-in-regulation among logged par-4 / par-5 holes. Returns
    /// `nil` when no eligible holes have been logged — render that as
    /// `-` rather than `0/0` per the brief.
    public var liveFIR: (made: Int, of: Int)? {
        let eligible = loggedHoleStats.filter { $0.par >= 4 }
        guard !eligible.isEmpty else { return nil }
        return (eligible.filter(\.fairwayInRegulation).count, eligible.count)
    }

    /// Total putts across logged holes.
    public var livePutts: Int {
        loggedHoleStats.reduce(0) { $0 + $1.putts }
    }

    /// Three-putt count across logged holes.
    public var liveThreePutts: Int {
        loggedHoleStats.filter(\.threePutt).count
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

    public var vsPar: Int {
        totalStrokes - playedPar
    }

    public var filledCount: Int {
        entries.reduce(0) { $0 + ($1.strokes == nil ? 0 : 1) }
    }

    public var currentHole: Hole {
        holes[holeIdx]
    }

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
        // Par 3 is a single shot to the green. The Play UI surfaces it through
        // the approach editor (target = Green) so the user's pick lands on
        // `entry.approach`; HoleStat / WHS / v1 schema all expect that pick on
        // `teeShotLie`. Coalesce so the domain reads it correctly.
        let teeLie: Lie?
        let approachLie: Lie?
        let obCount: Int
        let hazardCount: Int
        if hole.par == 3 {
            teeLie = approachDecoded.lie ?? teeDecoded.lie
            approachLie = nil
            obCount = approachDecoded.ob + teeDecoded.ob
            hazardCount = approachDecoded.hazard + teeDecoded.hazard
        } else {
            teeLie = teeDecoded.lie
            approachLie = approachDecoded.lie
            obCount = teeDecoded.ob + approachDecoded.ob
            hazardCount = teeDecoded.hazard + approachDecoded.hazard
        }
        return HoleStat(
            par: hole.par,
            strokes: strokes,
            putts: entry.putts,
            teeShotLie: teeLie,
            approachLie: approachLie,
            penaltyStrokes: entry.penaltyStrokes,
            outOfBoundsCount: obCount,
            hazardCount: hazardCount,
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
        // Par-5 "ON IN 2" shortcut — semantically identical to Green for
        // stats, but stored as a distinct value so the keypad's center
        // cell and the ON IN 2 button toggle independently.
        if raw == "On In 2" { return DecodedLie(lie: .green, ob: 0, hazard: 0) }
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
                case "Left": bunker = .bunkerLeft
                case "Right": bunker = .bunkerRight
                case "Long": bunker = .bunkerLong
                case "Short": bunker = .bunkerShort
                default: bunker = .bunkerLeft
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

/// JSON codec for `[HoleEntry]` ↔ `Data`. The draft repo trades in
/// opaque `entriesPayload: Data` (so Domain stays UI-agnostic); the
/// feature layer owns the schema and this helper centralises the codec
/// so call sites don't reach for a `JSONEncoder` each time.
public enum HoleEntriesCodec {
    public static func encode(_ entries: [HoleEntry]) -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data()
    }

    public static func decode(_ data: Data) -> [HoleEntry]? {
        try? JSONDecoder().decode([HoleEntry].self, from: data)
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
