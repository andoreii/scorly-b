import CoreGraphics
import ScorlyDesignSystem
import ScorlyDomain

/// "The Thread" projection. The redesigned Play screen renders a hole as
/// an ordered list of shot nodes (tee → cup) and raises a bottom sheet to
/// edit one at a time. None of that is new storage: a `ThreadNode` is a
/// *view* of the existing `HoleEntry` fields, and every edit routes back
/// through the same mutators the old per-phase sheets used
/// (`setTeeShotResult`, `setApproachResult`, `markApproachIn`,
/// `markARGIn`, …). `derivedStat` / `HoleStat` / the codec are untouched —
/// that's what keeps stat integrity across the redesign.
///
/// Logic mirrors the React prototype's `rpiNextDesc`: each result decides
/// the next node — a full shot that finds the green → a putt; a shot that
/// misses → a recovery chip; a putt that misses → another putt; a holed
/// shot/putt ends the hole.
public extension RoundPlayState {
    // MARK: - Slots

    /// Identifies which logical shot a node edits. The raw `HoleEntry`
    /// field(s) each slot reads/writes are listed on the accessors below.
    enum ShotSlot: Equatable, Hashable {
        case tee // par 4/5 tee — fairway mode
        case teeToGreen // par 3 tee — green mode (writes the approach fields)
        case second // par 5 lay-up — fairway mode
        case approach // approach — green mode
        case chip(Int) // around-the-green recovery — green mode
        case putt(Int) // putt — putt mode
    }

    /// One rendered row on the Thread.
    struct ThreadNode: Identifiable, Equatable {
        public let slot: ShotSlot
        public let displayIndex: Int // 1-based position in the thread
        public let title: String
        public let mode: TargetField.Mode
        public let logged: Bool
        public let good: Bool
        public let resultLabel: String?
        public let club: String?
        public let distance: Int?
        public let unit: DistanceDial.Unit
        public let distanceSubtitle: String
        public let directionOffset: CGFloat // -1…1, drives the mini tracer
        public let placement: TargetField.Pick?

        public var id: String {
            switch slot {
            case .tee: "tee"
            case .teeToGreen: "teeToGreen"
            case .second: "second"
            case .approach: "approach"
            case let .chip(shotIndex): "chip-\(shotIndex)"
            case let .putt(shotIndex): "putt-\(shotIndex)"
            }
        }
    }

    // MARK: - Node list (progressive reveal)

    /// The visible thread for a hole: every logged node plus the single
    /// next "open" node. Built from `HoleEntry` using the same gates the
    /// old UI used (`shouldShowLayupTab`, `approachResultImpliesARG`).
    func threadNodes(at index: Int) -> [ThreadNode] {
        guard entries.indices.contains(index), holes.indices.contains(index) else { return [] }
        let candidates = candidateSlots(at: index)
        // Progressive reveal: keep logged nodes + the first unlogged one.
        var visible: [ShotSlot] = []
        for slot in candidates {
            visible.append(slot)
            if !slotLogged(slot, at: index) { break }
        }
        return visible.enumerated().map { shotIndex, slot in node(for: slot, displayIndex: shotIndex + 1, at: index) }
    }

    /// Full ordered slot backbone for a hole, before reveal trimming.
    private func candidateSlots(at index: Int) -> [ShotSlot] {
        let hole = holes[index]
        var slots: [ShotSlot] = []

        if hole.par == 3 {
            slots.append(.teeToGreen)
        } else {
            slots.append(.tee)
            if hole.par == 5, shouldShowLayupTab(at: index) { slots.append(.second) }
            if !hasDrivenGreen(at: index) { slots.append(.approach) }
        }

        // Recovery chips — only when the approach left the green.
        if approachResultImpliesARG(at: index) {
            let logged = loggedChipCount(at: index)
            let needAnother = !(lastChipReachedGreen(at: index) || lastChipHoled(at: index))
            let count = max(logged + (needAnother ? 1 : 0), 1)
            for shotIndex in 0..<count {
                slots.append(.chip(shotIndex))
            }
        }

        // Putts — once the green is reached and nothing was holed off it.
        if greenReached(at: index), !shotHoled(at: index) {
            let recorded = recordedPuttCount(at: index)
            let pending = max(entries[index].putts, recorded) > recorded
            let count = max(recorded + (pending ? 1 : recorded == 0 ? 1 : 0), recorded)
            let shown = max(count, recorded == 0 ? 1 : recorded)
            for shotIndex in 0..<shown {
                slots.append(.putt(shotIndex))
            }
        }

        return slots
    }

    // MARK: - Per-slot reads

    func slotMode(_ slot: ShotSlot) -> TargetField.Mode {
        switch slot {
        case .tee, .second: .fairway
        case .teeToGreen, .approach, .chip: .green
        case .putt: .putt
        }
    }

    private func slotTitle(_ slot: ShotSlot, at index: Int) -> String {
        switch slot {
        case .tee, .teeToGreen: "Tee Shot"
        case .second: "Second"
        case .approach: "Approach"
        case .chip: "Chip"
        case .putt: "Putt"
        }
    }

    func slotLogged(_ slot: ShotSlot, at index: Int) -> Bool {
        let entry = entries[index]
        switch slot {
        case .tee: return entry.teeShot != nil
        case .teeToGreen, .approach: return entry.approach != nil
        case .second: return entry.layupLie != nil
        case let .chip(shotIndex):
            guard let shots = entry.argShots, shots.indices.contains(shotIndex) else { return false }
            return shots[shotIndex].lie != nil
        case let .putt(shotIndex): return shotIndex < recordedPuttCount(at: index)
        }
    }

    /// The raw lie value + modifier a slot currently holds.
    func slotValueModifier(_ slot: ShotSlot, at index: Int) -> (value: String?, modifier: String?) {
        let entry = entries[index]
        switch slot {
        case .tee: return (entry.teeShot, entry.teeShotModifier)
        case .teeToGreen, .approach: return (entry.approach, entry.approachModifier)
        case .second: return (entry.layupLie, entry.layupLieModifier)
        case let .chip(shotIndex):
            guard let shots = entry.argShots, shots.indices.contains(shotIndex) else { return (nil, nil) }
            return (shots[shotIndex].lie, shots[shotIndex].lieModifier)
        case .putt: return (nil, nil)
        }
    }

    func slotDistance(_ slot: ShotSlot, at index: Int) -> Int? {
        let entry = entries[index]
        switch slot {
        case .tee: return entry.teeShotDistance
        case .teeToGreen, .approach: return entry.approachDistance
        case .second: return entry.layupDistance
        case let .chip(shotIndex): return entry.argShots?[safe: shotIndex]?.distanceYards
        case let .putt(shotIndex): return entry.puttDistances[safe: shotIndex].flatMap { $0 }
        }
    }

    func slotClub(_ slot: ShotSlot, at index: Int) -> String? {
        let entry = entries[index]
        switch slot {
        case .tee: return entry.teeClub
        case .teeToGreen, .approach: return entry.approachClub
        case .second: return entry.layupClub
        case .chip, .putt: return nil
        }
    }

    /// Whether a slot offers a club picker (ARG / putts don't store one).
    func slotHasClub(_ slot: ShotSlot) -> Bool {
        switch slot {
        case .tee, .teeToGreen, .second, .approach: true
        case .chip, .putt: false
        }
    }

    func slotUnit(_ slot: ShotSlot) -> DistanceDial.Unit {
        slotMode(slot) == .putt ? .feet : .yards
    }

    private func slotDistanceSubtitle(_ slot: ShotSlot) -> String {
        switch slot {
        case .tee, .second: "Carry"
        case .teeToGreen, .approach, .chip: "To pin"
        case .putt: "Length"
        }
    }

    private func node(for slot: ShotSlot, displayIndex: Int, at index: Int) -> ThreadNode {
        let logged = slotLogged(slot, at: index)
        let (value, modifier) = slotValueModifier(slot, at: index)
        let good = nodeGood(slot, value: value, at: index)
        return ThreadNode(
            slot: slot,
            displayIndex: displayIndex,
            title: slotTitle(slot, at: index),
            mode: slotMode(slot),
            logged: logged,
            good: good,
            resultLabel: logged ? nodeResultLabel(slot, value: value, modifier: modifier, at: index) : nil,
            club: slotClub(slot, at: index),
            distance: slotDistance(slot, at: index),
            unit: slotUnit(slot),
            distanceSubtitle: slotDistanceSubtitle(slot),
            directionOffset: directionOffset(value),
            placement: logged ? approximatePlacement(slot, value: value, modifier: modifier, at: index) : nil
        )
    }

    func nodeGood(_ slot: ShotSlot, value: String?, at index: Int) -> Bool {
        switch slot {
        case .putt:
            return isPuttHoled(at: index) && isLastPutt(slot, at: index)
        default:
            return value == "Fairway" || value == "Green" || value == "On In 2" || value == RoundPlayState.holedShotRaw
        }
    }

    func nodeResultLabel(_ slot: ShotSlot, value: String?, modifier: String?, at index: Int) -> String {
        if case let .putt(shotIndex) = slot {
            if isPuttHoled(at: index), isLastPutt(slot, at: index) { return "HOLED" }
            if let ft = entries[index].puttDistances[safe: shotIndex].flatMap({ $0 }) { return "\(ft) FT" }
            return "PUTT"
        }
        guard let value else { return "—" }
        if value == RoundPlayState.holedShotRaw { return "HOLED" }
        if value == "Fairway" { return "FAIRWAY" }
        if value == "Green" || value == "On In 2" { return "ON GREEN" }
        if value.hasPrefix("OB ") {
            let direction = value.dropFirst(3).uppercased()
            return modifier == "Water" ? "WATER \(direction)" : "OB \(direction)"
        }
        if value.hasPrefix("Miss ") {
            let dir = value.dropFirst(5).uppercased()
            if modifier == "Bunker" { return "\(dir) BUNKER" }
            return slotMode(slot) == .green ? "MISS \(dir)" : "ROUGH \(dir)"
        }
        return value.uppercased()
    }

    // MARK: - State predicates

    private func recordedPuttCount(at index: Int) -> Int {
        entries[index].puttDistances.prefix { $0 != nil }.count
    }

    private func loggedChipCount(at index: Int) -> Int {
        guard let shots = entries[index].argShots else { return 0 }
        return shots.prefix { $0.lie != nil }.count
    }

    private func lastChipReachedGreen(at index: Int) -> Bool {
        guard let shots = entries[index].argShots, let last = shots.last(where: { $0.lie != nil }) else { return false }
        return last.lie == "Green"
    }

    private func lastChipHoled(at index: Int) -> Bool {
        guard let shots = entries[index].argShots, let last = shots.last(where: { $0.lie != nil }) else { return false }
        return last.lie == RoundPlayState.holedShotRaw
    }

    func shotHoled(at index: Int) -> Bool {
        if isApproachIn(at: index) { return true }
        if let shots = entries[index].argShots, shots.contains(where: { $0.lie == RoundPlayState.holedShotRaw }) {
            return true
        }
        return false
    }

    /// The green has been reached by a full/recovery shot (so the hole now
    /// proceeds to putting), and the ball wasn't holed off the surface.
    func greenReached(at index: Int) -> Bool {
        if shotHoled(at: index) { return false }
        let hole = holes[index]
        if hole.par >= 4, hasDrivenGreen(at: index) { return true }
        let approach = entries[index].approach
        if approach == "Green" || approach == "On In 2" { return true }
        if lastChipReachedGreen(at: index) { return true }
        return false
    }

    /// The hole has been signed off (strokes committed) — used to mark the
    /// final putt as holed for display.
    func holeFinalised(at index: Int) -> Bool {
        entries[index].strokes != nil
    }

    func isLastPutt(_ slot: ShotSlot, at index: Int) -> Bool {
        guard case let .putt(shotIndex) = slot else { return false }
        return shotIndex == recordedPuttCount(at: index) - 1
    }

    // MARK: - Running totals (for the live Hole Summary)

    /// Live gross score = swings logged so far + penalty strokes incurred,
    /// matching the prototype's `score = logged.length + pen`.
    func runningStrokes(at index: Int) -> Int {
        loggedShotNodeCount(at: index) + penaltyContribution(at: index)
    }

    func penaltyContribution(at index: Int) -> Int {
        derivedStat(for: index).effectivePenaltyStrokes
    }

    /// Live values for the Hole Summary card. `fir` / `gir` stay `.unknown`
    /// until the deciding shot is logged (rendered as "—"); `score` is nil
    /// on an untouched hole.
    func summaryStats(at index: Int) -> HoleSummaryStats {
        let hole = holes[index]
        let stat = derivedStat(for: index)
        let anyLogged = loggedShotNodeCount(at: index) > 0
        let teeLogged = hole.par == 3 ? slotLogged(.teeToGreen, at: index) : slotLogged(.tee, at: index)
        let greenDecided = hole.par == 3
            ? slotLogged(.teeToGreen, at: index)
            : slotLogged(.approach, at: index) || hasDrivenGreen(at: index) || lastChipReachedGreen(at: index) ||
            shotHoled(at: index)
        let fir: HitState = hole.par == 3
            ? .notApplicable
            : (teeLogged ? .from(stat.fairwayInRegulation) : .unknown)
        let gir: HitState = greenDecided ? .from(stat.greenInRegulation) : .unknown
        return HoleSummaryStats(
            // Surface the committed strokes (also covers the quick-score
            // fallback, where strokes is set without logging shots).
            score: entries[index].strokes ?? (anyLogged ? runningStrokes(at: index) : nil),
            fir: fir,
            gir: gir,
            putts: recordedPuttCount(at: index),
            pen: penaltyContribution(at: index)
        )
    }

    /// The hole has been holed out — a shot was holed, or putting reached
    /// a holed final putt (no pending putt left). Drives the "signed" /
    /// "holed in N" banners.
    func isHoleComplete(at index: Int) -> Bool {
        guard entries.indices.contains(index) else { return false }
        if shotHoled(at: index) { return true }
        guard greenReached(at: index) else { return false }
        return isPuttHoled(at: index)
    }

    func isPuttHoled(at index: Int) -> Bool {
        if let state = entries[index].puttCompletionState {
            return state == .holed
        }
        let recorded = recordedPuttCount(at: index)
        return recorded >= 1 && entries[index].putts <= recorded && holeFinalised(at: index)
    }

    private func loggedShotNodeCount(at index: Int) -> Int {
        let hole = holes[index]
        var count = 0
        if hole.par == 3 {
            if slotLogged(.teeToGreen, at: index) { count += 1 }
        } else {
            if slotLogged(.tee, at: index) { count += 1 }
            if slotLogged(.second, at: index) { count += 1 }
            if slotLogged(.approach, at: index) { count += 1 }
        }
        count += loggedChipCount(at: index)
        count += recordedPuttCount(at: index)
        return count
    }

    // MARK: - Writes

    /// Apply a tap result from the `TargetField` onto a slot, then keep
    /// the dependent state (and the running stroke count) valid.
    func applyPick(_ pick: TargetField.Pick, to slot: ShotSlot, at index: Int) {
        guard entries.indices.contains(index) else { return }
        // A dead-centre (pin) tap on a green-mode shot holes it out — route
        // through the same holed-out mutators the HOLED button uses.
        if pick.holed, slotMode(slot) == .green {
            setTargetPosition(pick.pos, for: slot, at: index)
            ensureHoledOut(slot, at: index)
            syncStrokes(at: index)
            return
        }
        switch slot {
        case .tee:
            setTeeShotResult(pick.value, at: index)
            entries[index].teeShotModifier = pick.modifier
            entries[index].teeTargetPosition = ShotTargetPosition(point: pick.pos)
        case .teeToGreen, .approach:
            setApproachResult(pick.value, at: index)
            entries[index].approachModifier = pick.modifier
            entries[index].approachTargetPosition = ShotTargetPosition(point: pick.pos)
        case .second:
            entries[index].layupLie = pick.value
            entries[index].layupLieModifier = pick.modifier
            entries[index].layupTargetPosition = ShotTargetPosition(point: pick.pos)
        case let .chip(shotIndex):
            setChip(value: pick.value, modifier: pick.modifier, slot: shotIndex, at: index)
            setTargetPosition(pick.pos, for: slot, at: index)
        case let .putt(shotIndex):
            recordPutt(holed: pick.holed, remaining: pick.proximityFeet, slot: shotIndex, at: index)
            setTargetPosition(pick.pos, for: slot, at: index)
        }
        syncStrokes(at: index)
    }

    /// Force the green-mode `slot` into its holed state (idempotent — a
    /// second pin tap won't toggle it back off).
    private func ensureHoledOut(_ slot: ShotSlot, at index: Int) {
        switch slot {
        case .teeToGreen, .approach:
            if !isApproachIn(at: index) { markApproachIn(at: index) }
        case let .chip(shotIndex):
            if !isARGIn(slot: shotIndex, at: index) { markARGIn(slot: shotIndex, at: index) }
        default:
            break
        }
    }

    /// Distance dial write.
    func setSlotDistance(_ distance: Int, to slot: ShotSlot, at index: Int) {
        guard entries.indices.contains(index) else { return }
        switch slot {
        case .tee: entries[index].teeShotDistance = distance
        case .teeToGreen, .approach: entries[index].approachDistance = distance
        case .second: entries[index].layupDistance = distance
        case let .chip(shotIndex): setChipDistance(distance, slot: shotIndex, at: index)
        case let .putt(shotIndex): setPuttDistance(distance, slot: shotIndex, at: index)
        }
    }

    func setSlotClub(_ club: String, to slot: ShotSlot, at index: Int) {
        guard entries.indices.contains(index) else { return }
        switch slot {
        case .tee: entries[index].teeClub = club
        case .teeToGreen, .approach: entries[index].approachClub = club
        case .second: entries[index].layupClub = club
        case .chip, .putt: break
        }
    }

    /// Hazard tag toggle for a full shot / chip. OB & Water set a penalty
    /// lie (direction reused from the current placement); Bunker sets a
    /// bunker lie; Unplayable bumps the manual penalty stroke.
    func applyHazard(_ hazard: HazardTag, to slot: ShotSlot, at index: Int) {
        guard entries.indices.contains(index) else { return }
        let (value, modifier) = slotValueModifier(slot, at: index)
        let dir = direction(from: value) ?? "Right"

        if hazard == .unplayable {
            entries[index].penaltyStrokes = entries[index].penaltyStrokes > 0 ? 0 : 1
            syncStrokes(at: index)
            return
        }

        // Bunker / OB / Water are lie outcomes. Preserve the independently
        // selected radar coordinate while routing the lie through applyPick.
        let targetPosition = currentTargetPosition(for: slot, at: index)
        var newValue: String?
        var newModifier: String?
        var label = ""
        switch hazard {
        case .bunker:
            let isOn = value?.hasPrefix("Miss ") == true && modifier == "Bunker"
            newValue = isOn ? nil : "Miss \(dir)"
            newModifier = isOn ? nil : "Bunker"
            label = "BUNKER"
        case .ob:
            let isOn = value?.hasPrefix("OB ") == true && modifier != "Water"
            newValue = isOn ? nil : "OB \(dir)"
            label = "OB"
        case .water:
            let isOn = value?.hasPrefix("OB ") == true && modifier == "Water"
            newValue = isOn ? nil : "OB \(dir)"
            newModifier = isOn ? nil : "Water"
            label = "WATER"
        case .unplayable:
            return
        }
        applyPick(latPick(value: newValue, modifier: newModifier, label: label), to: slot, at: index)
        setTargetPosition(targetPosition?.point, for: slot, at: index)
    }

    /// Builds a non-good lateral/penalty `Pick` (the hazard tags and the
    /// reconstructed-placement helpers all share this shape).
    private func latPick(value: String?, modifier: String?, label: String) -> TargetField.Pick {
        TargetField.Pick(value: value, pos: CGPoint(x: 0.5, y: 0.5), good: false, label: label, modifier: modifier)
    }

    /// Whether the given green-mode `slot` is currently holed — drives the
    /// HOLED button's selected state (distinct from "good", which is true
    /// for any on-green result).
    func isSlotHoled(_ slot: ShotSlot, at index: Int) -> Bool {
        switch slot {
        case .teeToGreen, .approach: return isApproachIn(at: index)
        case let .chip(shotIndex): return isARGIn(slot: shotIndex, at: index)
        case .putt: return isPuttHoled(at: index) && isLastPutt(slot, at: index)
        default: return false
        }
    }

    /// "Holed ✓" on a full shot or chip (ace, drained approach, chip-in).
    func holeOutShot(_ slot: ShotSlot, at index: Int) {
        switch slot {
        case .teeToGreen, .approach:
            markApproachIn(at: index)
        case let .chip(shotIndex):
            markARGIn(slot: shotIndex, at: index)
        default:
            break
        }
        syncStrokes(at: index)
    }

    /// "Missed · add putt" — append another pending putt after the current.
    func addPutt(after slot: ShotSlot, at index: Int) {
        guard case let .putt(shotIndex) = slot else { return }
        let recorded = recordedPuttCount(at: index)
        // Ensure the current putt has a length, then open a new pending one.
        if recorded <= shotIndex { padPuttDistances(to: shotIndex + 1, at: index) }
        entries[index].putts = max(entries[index].putts, recordedPuttCount(at: index) + 1)
        entries[index].puttCompletionState = .open
        syncStrokes(at: index)
    }

    func pinPosition(at index: Int) -> String? {
        entries[index].pinPosition
    }

    func setPinPosition(_ value: String?, at index: Int) {
        entries[index].pinPosition = value
    }

    // MARK: - Write internals

    private func setChip(value: String?, modifier: String?, slot shotIndex: Int, at index: Int) {
        var shots = entries[index].argShots ?? []
        while shots.count <= shotIndex {
            shots.append(ARGShotEntry())
        }
        shots[shotIndex].lie = value
        shots[shotIndex].lieModifier = modifier
        entries[index].argShots = shots
    }

    private func setChipDistance(_ distance: Int, slot shotIndex: Int, at index: Int) {
        var shots = entries[index].argShots ?? []
        while shots.count <= shotIndex {
            shots.append(ARGShotEntry())
        }
        shots[shotIndex].distanceYards = distance
        entries[index].argShots = shots
    }

    private func recordPutt(holed: Bool, remaining: Int?, slot shotIndex: Int, at index: Int) {
        padPuttDistances(to: shotIndex + 1, at: index)
        if holed {
            entries[index].putts = recordedPuttCount(at: index)
            entries[index].puttCompletionState = .holed
        } else {
            entries[index].putts = recordedPuttCount(at: index) + 1
            entries[index].puttCompletionState = .open
        }
    }

    private func setPuttDistance(_ distance: Int, slot shotIndex: Int, at index: Int) {
        padPuttDistances(to: shotIndex + 1, at: index)
        entries[index].puttDistances[shotIndex] = distance
    }

    /// Grow `puttDistances` so index `count-1` exists, seeding new slots
    /// with a sensible default length rather than nil (so a recorded putt
    /// always carries a distance for SG).
    private func padPuttDistances(to count: Int, at index: Int) {
        var dists = entries[index].puttDistances
        while dists.count < count {
            dists.append(dists.last.flatMap { $0 } ?? 6)
        }
        entries[index].puttDistances = dists
    }

    /// Recompute the committed gross score from the logged nodes. Left nil
    /// while the hole is untouched so it still counts as par on nav.
    private func syncStrokes(at index: Int) {
        let count = loggedShotNodeCount(at: index)
        let pen = penaltyContribution(at: index)
        entries[index].strokes = (count + pen) > 0 ? count + pen : nil
    }

    // MARK: - Placement reconstruction (no schema change)

    private func direction(from value: String?) -> String? {
        guard let value else { return nil }
        for key in ["Left", "Right", "Long", "Short"] where value.hasSuffix(key) {
            return key
        }
        return nil
    }

    private func directionOffset(_ value: String?) -> CGFloat {
        if value?.hasSuffix("Left") == true { return -0.7 }
        if value?.hasSuffix("Right") == true { return 0.7 }
        return 0
    }
}
