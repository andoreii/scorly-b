import Foundation
import Observation
import ScorlyDomain

/// One hole's worth of in-progress input. `strokes` is nullable so the
/// Play screen can render par as a placeholder before logging. `teeShot` /
/// `approach` are raw `LieKeypad` strings with an optional "Bunker"/"Water"
/// modifier, decoded into a typed `HoleStat` only when derivation runs.
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
    /// Yards from the pin where the approach finished (par 4/5) or
    /// where the tee shot finished (par 3). Optional — when nil, the
    /// SG calculator falls back to a lie-based default.
    public var approachLandingDistance: Int?
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
    public var pinPosition: String?
    public var penaltyStrokes: Int
    public var upAndDownOverride: Bool?
    public var sandSaveOverride: Bool?

    public init(
        strokes: Int? = nil,
        putts: Int = 2,
        puttDistances: [Int?] = [],
        teeShot: String? = nil,
        teeShotModifier: String? = nil,
        teeClub: String? = nil,
        teeShotDistance: Int? = nil,
        approach: String? = nil,
        approachModifier: String? = nil,
        approachClub: String? = nil,
        approachDistance: Int? = nil,
        approachLandingDistance: Int? = nil,
        argShots: [ARGShotEntry]? = nil,
        layupLie: String? = nil,
        layupLieModifier: String? = nil,
        layupClub: String? = nil,
        layupDistance: Int? = nil,
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
        self.approachLandingDistance = approachLandingDistance
        self.argShots = argShots
        self.layupLie = layupLie
        self.layupLieModifier = layupLieModifier
        self.layupClub = layupClub
        self.layupDistance = layupDistance
        self.pinPosition = pinPosition
        self.penaltyStrokes = penaltyStrokes
        self.upAndDownOverride = upAndDownOverride
        self.sandSaveOverride = sandSaveOverride
    }
}

/// Raw-string mirror of `ScorlyDomain.ARGShot` for the live-round editor,
/// decoded into a typed `Lie` at `derivedStat` time.
public struct ARGShotEntry: Equatable, Sendable, Codable {
    public var lie: String?
    public var lieModifier: String?
    public var distanceYards: Int?

    public init(lie: String? = nil, lieModifier: String? = nil, distanceYards: Int? = nil) {
        self.lie = lie
        self.lieModifier = lieModifier
        self.distanceYards = distanceYards
    }
}

/// Live-round state — owns the slice of holes being played, the
/// per-hole entries, the cursor index, and which shot block is expanded.
/// Created when the player taps "Tee off" and discarded on exit.
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
        entry.argShots = nil
        entry.layupLie = nil
        entry.layupLieModifier = nil
        entry.layupClub = nil
        entry.layupDistance = nil
    }

    /// Mutates a tee-shot result while keeping its dependent approach state valid.
    public func setTeeShotResult(_ result: String?, at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries[index].teeShot = result
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

    /// Reslice the round to a different holes-played mode mid-play, remapping
    /// existing entries by hole number. Holes dropped from the new slice lose
    /// their entries; the cursor stays on the same hole when possible.
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

    /// HoleStat snapshots for every logged hole, via `derivedStat(for:)` so
    /// live and sign-and-file values agree exactly.
    public var loggedHoleStats: [HoleStat] {
        entries.indices.compactMap { idx in
            entries[idx].strokes != nil ? derivedStat(for: idx) : nil
        }
    }

    /// Greens-in-regulation among logged holes only, so unplayed holes
    /// never dilute the percentage.
    public var liveGIR: (made: Int, of: Int) {
        let logged = loggedHoleStats
        return (logged.filter(\.greenInRegulation).count, logged.count)
    }

    /// Fairways-in-regulation among logged par-4 / par-5 holes. Returns nil
    /// when no eligible holes are logged — render as `-`, not `0/0`.
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

    /// Par summed across logged holes only (matches the "+ vs PAR" tally).
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

    /// If the hole at `index` was never logged, treat it as par, so totals
    /// and the payload reflect "untouched == par" instead of zero.
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

    /// Build a `HoleStat` snapshot of the current entry to drive the
    /// FIR / GIR / 3-putt chips. Falls back to `hole.par` when strokes
    /// haven't been logged yet.
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
        // Par 3 is one shot to the green, surfaced via the approach editor,
        // but HoleStat expects that pick on `teeShotLie` — coalesce here.
        let teeLie: Lie?
        let approachLie: Lie?
        if hole.par == 3 {
            teeLie = approachDecoded.lie ?? teeDecoded.lie
            approachLie = nil
        } else {
            teeLie = teeDecoded.lie
            approachLie = approachDecoded.lie
        }
        let penaltyEvents: [PenaltyEvent] = teeDecoded.penaltyEvents + approachDecoded.penaltyEvents
        // Filter nil distances (putt happened but wasn't measured); empty
        // list stays `[]`, distinct from nil ("never opened putting sheet").
        let loggedPutts = entry.puttDistances.compactMap { $0 }
        let puttDistances: [Int]? = entry.puttDistances.isEmpty ? nil : loggedPutts

        // Each ARG entry needs both a lie and distance to contribute;
        // partial rows fall back to lie-based defaults at SG time.
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

    /// Number of around-the-green shots implied by strokes / putts / par.
    /// Returns 0 when the math hasn't settled yet (no strokes logged, or
    /// putts > strokes mid-edit).
    public func inferredARGCount(at index: Int) -> Int {
        guard entries.indices.contains(index), holes.indices.contains(index) else { return 0 }
        let entry = entries[index]
        guard let strokes = entry.strokes, strokes > 0 else { return 0 }
        return max(0, strokes - preARGShotCount(at: index) - entry.putts)
    }

    private func approachShotNumber(at index: Int) -> Int {
        guard holes.indices.contains(index) else { return 2 }
        return switch holes[index].par {
        case 3: 1
        case 5 where !isApproachOnInTwo(at: index): 3
        default: 2
        }
    }

    private func preARGShotCount(at index: Int) -> Int {
        guard holes.indices.contains(index) else { return 2 }
        // Shots before any ARG chip: 1 for par 3, 2 for par 4, 3 for par 5 (unless on in 2).
        return switch holes[index].par {
        case 3: 1
        case 5 where !isApproachOnInTwo(at: index): 3
        default: 2
        }
    }

    private func approachResultImpliesARG(at index: Int) -> Bool {
        guard entries.indices.contains(index) else { return false }
        guard let result = entries[index].approach else { return false }
        if result == "Green" || result == "On In 2" || result == Self.holedShotRaw { return false }
        if result.hasPrefix("OB ") { return false }
        return true
    }

    private func restoreDefaultPutts(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries[index].putts = 2
        entries[index].puttDistances = []
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
    /// closest `Lie` plus any implied `PenaltyEvent`s.
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
        // "On In 2" is stats-equivalent to Green but kept distinct so the
        // keypad's center cell and ON IN 2 button toggle independently.
        if raw == "On In 2" { return DecodedLie(lie: .green) }
        // Legacy single-string entry, pre-dates the modifier split.
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

    /// Maps the keypad's direction suffix to a `PenaltyDirection`; unknown
    /// suffixes record the event without a direction.
    private static func penaltyDirection(from suffix: String) -> PenaltyDirection? {
        switch suffix {
        case "Left": .left
        case "Right": .right
        case "Long": .long
        case "Short": .short
        default: nil
        }
    }

    private static let holedShotRaw = "In"
}

/// JSON codec for `[HoleEntry]` ↔ `Data`, since the draft repo stores
/// entries as opaque `Data` to keep Domain UI-agnostic.
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
