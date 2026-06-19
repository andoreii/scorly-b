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
    public var radarPositionVersion: Int?
    public var strokes: Int?
    public var putts: Int
    public var puttDistances: [Int?]
    public var puttCompletionState: PuttCompletionState?
    public var teeShot: String?
    public var teeShotModifier: String?
    public var teeClub: String?
    public var teeShotDistance: Int?
    public var teeTargetPosition: ShotTargetPosition?
    public var approach: String?
    public var approachModifier: String?
    public var approachClub: String?
    public var approachDistance: Int?
    /// Yards from the pin where the approach finished (par 4/5) or
    /// where the tee shot finished (par 3). Optional — when nil, the
    /// SG calculator falls back to a lie-based default.
    public var approachLandingDistance: Int?
    public var approachTargetPosition: ShotTargetPosition?
    /// One entry per around-the-green shot, ordered by stroke. Length
    /// is expected to match the inferred ARG count. Optional — missing
    /// entries fall back to lie-based defaults at SG time.
    public var argShots: [ARGShotEntry]?
    /// Par-5 only: lie where the layup landed, as the keypad raw
    /// string (decoded into a typed `Lie` at `derivedStat` time).
    public var layupLie: String?
    public var layupLieModifier: String?
    public var layupClub: String?
    /// Par-5 only: yards remaining to the pin after the layup.
    public var layupDistance: Int?
    public var layupTargetPosition: ShotTargetPosition?
    public var puttTargetPositions: [ShotTargetPosition?]?
    public var pinPosition: String?
    public var penaltyStrokes: Int
    public var upAndDownOverride: Bool?
    public var sandSaveOverride: Bool?

    public init(
        radarPositionVersion: Int? = 1,
        strokes: Int? = nil,
        putts: Int = 2,
        puttDistances: [Int?] = [],
        puttCompletionState: PuttCompletionState? = .open,
        teeShot: String? = nil,
        teeShotModifier: String? = nil,
        teeClub: String? = nil,
        teeShotDistance: Int? = nil,
        teeTargetPosition: ShotTargetPosition? = nil,
        approach: String? = nil,
        approachModifier: String? = nil,
        approachClub: String? = nil,
        approachDistance: Int? = nil,
        approachLandingDistance: Int? = nil,
        approachTargetPosition: ShotTargetPosition? = nil,
        argShots: [ARGShotEntry]? = nil,
        layupLie: String? = nil,
        layupLieModifier: String? = nil,
        layupClub: String? = nil,
        layupDistance: Int? = nil,
        layupTargetPosition: ShotTargetPosition? = nil,
        puttTargetPositions: [ShotTargetPosition?] = [],
        pinPosition: String? = nil,
        penaltyStrokes: Int = 0,
        upAndDownOverride: Bool? = nil,
        sandSaveOverride: Bool? = nil
    ) {
        self.radarPositionVersion = radarPositionVersion
        self.strokes = strokes
        self.putts = putts
        self.puttDistances = puttDistances
        self.puttCompletionState = puttCompletionState
        self.teeShot = teeShot
        self.teeShotModifier = teeShotModifier
        self.teeClub = teeClub
        self.teeShotDistance = teeShotDistance
        self.teeTargetPosition = teeTargetPosition
        self.approach = approach
        self.approachModifier = approachModifier
        self.approachClub = approachClub
        self.approachDistance = approachDistance
        self.approachLandingDistance = approachLandingDistance
        self.approachTargetPosition = approachTargetPosition
        self.argShots = argShots
        self.layupLie = layupLie
        self.layupLieModifier = layupLieModifier
        self.layupClub = layupClub
        self.layupDistance = layupDistance
        self.layupTargetPosition = layupTargetPosition
        self.puttTargetPositions = puttTargetPositions
        self.pinPosition = pinPosition
        self.penaltyStrokes = penaltyStrokes
        self.upAndDownOverride = upAndDownOverride
        self.sandSaveOverride = sandSaveOverride
    }
}

/// Raw-string mirror of `ScorlyDomain.ARGShot` for the live-round
/// editor. The lie string matches the `LieKeypad` vocabulary (e.g.
/// "Miss Left", "Miss Long") with an optional "Bunker" / "Water"
/// modifier, decoded into a typed `Lie` at `derivedStat` time.
public struct ARGShotEntry: Equatable, Sendable, Codable {
    public var lie: String?
    public var lieModifier: String?
    public var distanceYards: Int?
    public var targetPosition: ShotTargetPosition?

    public init(
        lie: String? = nil,
        lieModifier: String? = nil,
        distanceYards: Int? = nil,
        targetPosition: ShotTargetPosition? = nil
    ) {
        self.lie = lie
        self.lieModifier = lieModifier
        self.distanceYards = distanceYards
        self.targetPosition = targetPosition
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
    public private(set) var setupForm: RoundSetupForm
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
        case layup
        case approach
        case arg
        case putts
    }

    public init(
        course: Course,
        teeId: UUID?,
        holesPlayed: HolesPlayed,
        setupForm: RoundSetupForm = RoundSetupForm()
    ) {
        self.course = course
        tee = course.tees.first(where: { $0.id == teeId }) ?? course.tees.first
        var setupForm = setupForm
        setupForm.holesPlayed = holesPlayed
        self.setupForm = setupForm
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
        startedAt: Date,
        setupForm: RoundSetupForm = RoundSetupForm()
    ) {
        self.course = course
        tee = course.tees.first(where: { $0.id == teeId }) ?? course.tees.first
        var setupForm = setupForm
        setupForm.holesPlayed = holesPlayed
        self.setupForm = setupForm
        self.holesPlayed = holesPlayed
        self.startedAt = startedAt

        let slice = Self.sliceHoles(course: course, holesPlayed: holesPlayed)
        holes = slice
        let raw = entries.count == slice.count
            ? entries
            : Array(repeating: HoleEntry(), count: slice.count)
        self.entries = zip(slice, raw).map { hole, entry in
            Self.normalizeEntry(entry, on: hole)
        }
        self.holeIdx = max(0, min(slice.count - 1, holeIdx))
        openShot = .none
        scorecardOpen = false
        penaltySheetOpen = false
    }

    /// Repair older drafts that predate tee-shot invariants.
    private static func normalizeEntry(_ entry: HoleEntry, on hole: Hole) -> HoleEntry {
        var normalized = entry
        if normalized.teeShot?.hasPrefix("OB ") == true {
            normalized.teeShotDistance = nil
        }
        if hole.par >= 4, normalized.teeShot == "Green" {
            normalized.teeShotModifier = nil
            clearApproach(in: &normalized)
        }
        return normalized
    }

    private static func clearApproach(in entry: inout HoleEntry) {
        entry.approach = nil
        entry.approachModifier = nil
        entry.approachClub = nil
        entry.approachDistance = nil
        entry.approachLandingDistance = nil
        entry.approachTargetPosition = nil
        entry.argShots = nil
        entry.layupLie = nil
        entry.layupLieModifier = nil
        entry.layupClub = nil
        entry.layupDistance = nil
        entry.layupTargetPosition = nil
    }

    /// Mutates a tee-shot result while keeping its dependent approach state valid.
    public func setTeeShotResult(_ result: String?, at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries[index].teeShot = result
        entries[index].teeTargetPosition = nil
        if result?.hasPrefix("OB ") == true {
            entries[index].teeShotDistance = nil
        }
        if holes[index].par >= 4, result == "Green" {
            entries[index].teeShotModifier = nil
            Self.clearApproach(in: &entries[index])
        }
    }

    /// Mutates the approach result while clearing dependent chip
    /// detail when the result no longer creates a playable missed-green
    /// recovery.
    public func setApproachResult(_ result: String?, at index: Int) {
        guard entries.indices.contains(index) else { return }
        if entries[index].approach == Self.holedShotRaw, result != Self.holedShotRaw {
            restoreDefaultPutts(at: index)
        }
        entries[index].approach = result
        entries[index].approachTargetPosition = nil
        if result == "Green" || result == "On In 2" || result == Self.holedShotRaw || result?.hasPrefix("OB ") == true {
            entries[index].approachLandingDistance = nil
            entries[index].argShots = nil
        }
        if result == "On In 2" {
            entries[index].approachModifier = nil
        }
    }

    public func hasDrivenGreen(at index: Int) -> Bool {
        entries.indices.contains(index)
            && holes[index].par >= 4
            && entries[index].teeShot == "Green"
    }

    public func isApproachOnInTwo(at index: Int) -> Bool {
        entries.indices.contains(index) && entries[index].approach == "On In 2"
    }

    public func shouldShowLayupTab(at index: Int) -> Bool {
        guard entries.indices.contains(index), holes.indices.contains(index) else { return false }
        return holes[index].par == 5
            && !hasDrivenGreen(at: index)
            && !isApproachOnInTwo(at: index)
    }

    public func shouldShowARGTab(at index: Int) -> Bool {
        inferredARGCount(at: index) > 0 && approachResultImpliesARG(at: index)
    }

    public func markApproachIn(at index: Int) {
        guard entries.indices.contains(index), holes.indices.contains(index) else { return }
        if isApproachIn(at: index) {
            entries[index].approach = nil
            entries[index].approachModifier = nil
            entries[index].approachLandingDistance = nil
            restoreDefaultPutts(at: index)
            entries[index].strokes = nil
            return
        }

        entries[index].approach = Self.holedShotRaw
        entries[index].approachModifier = nil
        entries[index].approachLandingDistance = nil
        entries[index].argShots = nil
        entries[index].putts = 0
        entries[index].puttDistances = []
        entries[index].puttCompletionState = .open
        entries[index].strokes = approachShotNumber(at: index)
    }

    public func isApproachIn(at index: Int) -> Bool {
        guard entries.indices.contains(index) else { return false }
        return entries[index].approach == Self.holedShotRaw
    }

    public func markARGIn(slot: Int, at index: Int) {
        guard entries.indices.contains(index), holes.indices.contains(index), slot >= 0 else { return }
        var current = entries[index].argShots ?? []
        while current.count <= slot {
            current.append(ARGShotEntry())
        }

        if current[slot].lie == Self.holedShotRaw {
            current[slot].lie = nil
            current[slot].lieModifier = nil
            entries[index].argShots = current.isEmpty ? nil : current
            restoreDefaultPutts(at: index)
            entries[index].strokes = preARGShotCount(at: index) + slot + 1 + entries[index].putts
            return
        }

        entries[index].putts = 0
        entries[index].puttDistances = []
        entries[index].puttCompletionState = .open
        entries[index].strokes = preARGShotCount(at: index) + slot + 1
        current[slot].lie = Self.holedShotRaw
        current[slot].lieModifier = nil
        entries[index].argShots = Array(current.prefix(slot + 1))
    }

    public func isARGIn(slot: Int, at index: Int) -> Bool {
        guard entries.indices.contains(index), slot >= 0 else { return false }
        guard let shots = entries[index].argShots, shots.indices.contains(slot) else { return false }
        return shots[slot].lie == Self.holedShotRaw
    }

    public func updateSetup(_ form: RoundSetupForm) {
        setupForm = form
        setupForm.holesPlayed = holesPlayed
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
        setupForm.holesPlayed = newValue
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
        let teeDecoded = Self.decodeLie(
            entry.teeShot,
            modifier: entry.teeShotModifier,
            target: .fairway,
            phase: .tee
        )
        let approachDecoded = Self.decodeLie(
            entry.approach,
            modifier: entry.approachModifier,
            target: .green,
            phase: .approach
        )
        // Par 3 is a single shot to the green. The Play UI surfaces it through
        // the approach editor (target = Green) so the user's pick lands on
        // `entry.approach`; HoleStat / WHS / v1 schema all expect that pick on
        // `teeShotLie`. Coalesce so the domain reads it correctly.
        let teeLie: Lie?
        let approachLie: Lie?
        if hole.par == 3 {
            teeLie = approachDecoded.lie ?? teeDecoded.lie
            approachLie = nil
        } else {
            teeLie = teeDecoded.lie
            approachLie = approachDecoded.lie
        }
        // Penalty events come from the keypad outcomes (the lie strings
        // "OB Left", "Miss Long" with the optional Water modifier).
        // Tee and approach contributions concatenate in stroke order.
        let penaltyEvents: [PenaltyEvent] = teeDecoded.penaltyEvents + approachDecoded.penaltyEvents
        // Collect only the entries the player actually logged. A nil
        // value in `puttDistances` means "this putt happened but no
        // distance was recorded"; the SG calculator wants a clean
        // `[Int]` so we filter. A wholly empty list still passes
        // through as an empty `[]` — distinct from "never opened the
        // putting sheet" (nil).
        let loggedPutts = entry.puttDistances.compactMap { $0 }
        let puttDistances: [Int]? = entry.puttDistances.isEmpty ? nil : loggedPutts

        // Decode ARG entries. Each entry needs both a lie and a
        // distance to contribute; partial rows are dropped (the SG
        // calculator falls back to the lie-based default for that
        // slot). Same for layup.
        let argShots: [ARGShot]? = entry.argShots.flatMap { rawEntries in
            let decoded: [ARGShot] = rawEntries.enumerated().compactMap { slot, raw in
                guard let lieString = raw.lie,
                      let distance = raw.distanceYards ?? (slot == 0 ? entry.approachLandingDistance : nil),
                      distance > 0,
                      let lie = Self.decodeLie(lieString, modifier: raw.lieModifier, target: .green).lie
                else { return nil }
                return ARGShot(lie: lie, distanceToPinYards: distance)
            }
            return decoded.isEmpty ? nil : decoded
        }
        let layupLie = entry.layupLie.flatMap {
            Self.decodeLie($0, modifier: entry.layupLieModifier, target: .fairway).lie
        }
        let layupDistance = layupLie == nil ? nil : entry.layupDistance ?? entry.approachDistance

        return HoleStat(
            par: hole.par,
            strokes: strokes,
            putts: entry.putts,
            teeShotLie: teeLie,
            approachLie: approachLie,
            penaltyStrokes: entry.penaltyStrokes,
            penaltyEvents: penaltyEvents,
            upAndDownSuccess: entry.upAndDownOverride ?? false,
            sandSaveSuccess: entry.sandSaveOverride ?? false,
            teeShotDistance: entry.teeShotDistance,
            approachDistance: entry.approachDistance,
            puttDistances: puttDistances,
            teeClub: entry.teeClub,
            approachClub: entry.approachClub,
            pinPosition: entry.pinPosition,
            approachLandingDistance: entry.approachLandingDistance,
            argShots: argShots,
            layupLie: layupLie,
            layupDistance: layupDistance
        )
    }

    /// Number of around-the-green shots implied by the current entry's
    /// strokes / putts / par. Drives both the SG calculator chip-phase
    /// count and the UI's conditional rendering of the ARG block.
    /// Returns 0 when the math hasn't settled (no strokes logged yet,
    /// or putts > strokes from a mid-edit state).
    public func inferredARGCount(at index: Int) -> Int {
        guard entries.indices.contains(index), holes.indices.contains(index) else { return 0 }
        let entry = entries[index]
        guard let strokes = entry.strokes, strokes > 0 else { return 0 }
        return max(0, strokes - preARGShotCount(at: index) - entry.putts)
    }

    func approachShotNumber(at index: Int) -> Int {
        guard holes.indices.contains(index) else { return 2 }
        return switch holes[index].par {
        case 3: 1
        case 5 where !isApproachOnInTwo(at: index): 3
        default: 2
        }
    }

    func preARGShotCount(at index: Int) -> Int {
        guard holes.indices.contains(index) else { return 2 }
        // Par 3 with off-green tee: chip count = strokes - 1 (tee) - putts.
        // Par 4: chip count = strokes - 2 (tee + approach) - putts.
        // Par 5: chip count = strokes - 3 (tee + 2nd shot + approach) - putts.
        return switch holes[index].par {
        case 3: 1
        case 5 where !isApproachOnInTwo(at: index): 3
        default: 2
        }
    }

    func approachResultImpliesARG(at index: Int) -> Bool {
        guard entries.indices.contains(index) else { return false }
        guard let result = entries[index].approach else { return false }
        if result == "Green" || result == "On In 2" || result == Self.holedShotRaw { return false }
        if result.hasPrefix("OB ") { return false }
        return true
    }

    func restoreDefaultPutts(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries[index].putts = 2
        entries[index].puttDistances = []
        entries[index].puttCompletionState = .open
        entries[index].puttTargetPositions = []
    }

    // MARK: - Lie decoding

    private struct DecodedLie {
        let lie: Lie?
        let penaltyEvents: [PenaltyEvent]

        init(lie: Lie?, penaltyEvents: [PenaltyEvent] = []) {
            self.lie = lie
            self.penaltyEvents = penaltyEvents
        }
    }

    /// Maps a `LieKeypad` raw direction + optional modifier into the
    /// closest `Lie` enum plus any penalty event the outcome implies.
    /// The keypad emits direction strings ("Fairway", "Green",
    /// "Miss …", "OB …") alongside an optional "Bunker" / "Water"
    /// modifier; this collapses them into the `Lie` rawValues the
    /// domain expects, routing OB / hazard outcomes into typed
    /// `PenaltyEvent`s with direction parsed from the suffix.
    private static func decodeLie(
        _ raw: String?,
        modifier: String?,
        target: Lie,
        phase: PenaltyPhase? = nil
    ) -> DecodedLie {
        guard let raw else { return DecodedLie(lie: nil) }
        if raw == "Fairway" { return DecodedLie(lie: .fairway) }
        if raw == "Green" { return DecodedLie(lie: .green) }
        if raw == Self.holedShotRaw { return DecodedLie(lie: .green) }
        // Par-5 "ON IN 2" shortcut — semantically identical to Green for
        // stats, but stored as a distinct value so the keypad's center
        // cell and the ON IN 2 button toggle independently.
        if raw == "On In 2" { return DecodedLie(lie: .green) }
        // Legacy single-string entries (back-compat for any data that
        // pre-dated the modifier split).
        if raw == "Bunker" { return DecodedLie(lie: .bunkerLeft) }
        if raw == "Water Hazard" {
            return DecodedLie(lie: nil, penaltyEvents: [PenaltyEvent(kind: .hazard, phase: phase)])
        }

        if raw.hasPrefix("OB ") {
            // Water modifier on an OB direction reclassifies the outcome
            // as a hazard (the ball is findable in water, not lost OB).
            let direction = Self.penaltyDirection(from: String(raw.dropFirst(3)))
            let kind: PenaltyKind = modifier == "Water" ? .hazard : .outOfBounds
            return DecodedLie(
                lie: nil,
                penaltyEvents: [PenaltyEvent(kind: kind, direction: direction, phase: phase)]
            )
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
                return DecodedLie(lie: bunker)
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
            return DecodedLie(lie: lie)
        }
        return DecodedLie(lie: nil)
    }

    /// Maps the keypad's direction suffix ("Left", "Right", "Long",
    /// "Short") to a `PenaltyDirection`. Anything else (the keypad's
    /// "Other" fallback or future labels) becomes nil — the event is
    /// still recorded, just without a direction.
    private static func penaltyDirection(from suffix: String) -> PenaltyDirection? {
        switch suffix {
        case "Left": .left
        case "Right": .right
        case "Long": .long
        case "Short": .short
        default: nil
        }
    }

    static let holedShotRaw = "In"
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
