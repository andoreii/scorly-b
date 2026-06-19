import CoreGraphics
import ScorlyDesignSystem

/// Rebuilds a `TargetField.Pick` so a logged marker can be redrawn. New
/// entries use their persisted normalized coordinate; legacy entries fall
/// back to an approximate position inferred from the stored lie.
extension RoundPlayState {
    private static let placeCX: CGFloat = 0.5
    private static let placeCY: CGFloat = 0.493

    func setTargetPosition(_ point: CGPoint?, for slot: ShotSlot, at index: Int) {
        let position = point.map(ShotTargetPosition.init(point:))
        switch slot {
        case .tee: entries[index].teeTargetPosition = position
        case .teeToGreen, .approach: entries[index].approachTargetPosition = position
        case .second: entries[index].layupTargetPosition = position
        case let .chip(shotIndex):
            var shots = entries[index].argShots ?? []
            while shots.count <= shotIndex {
                shots.append(ARGShotEntry())
            }
            shots[shotIndex].targetPosition = position
            entries[index].argShots = shots
        case let .putt(shotIndex):
            var positions = entries[index].puttTargetPositions ?? []
            while positions.count <= shotIndex {
                positions.append(nil)
            }
            positions[shotIndex] = position
            entries[index].puttTargetPositions = positions
        }
    }

    func currentTargetPosition(for slot: ShotSlot, at index: Int) -> ShotTargetPosition? {
        switch slot {
        case .tee: entries[index].teeTargetPosition
        case .teeToGreen, .approach: entries[index].approachTargetPosition
        case .second: entries[index].layupTargetPosition
        case let .chip(shotIndex): entries[index].argShots?[safe: shotIndex]?.targetPosition
        case let .putt(shotIndex): (entries[index].puttTargetPositions ?? [])[safe: shotIndex].flatMap { $0 }
        }
    }

    func approximatePlacement(
        _ slot: ShotSlot,
        value: String?,
        modifier: String?,
        at index: Int
    ) -> TargetField.Pick? {
        let good = nodeGood(slot, value: value, at: index)
        let label = nodeResultLabel(slot, value: value, modifier: modifier, at: index)
        if let position = currentTargetPosition(for: slot, at: index) {
            let proximity = slotDistance(slot, at: index)
            let holed = isSlotHoled(slot, at: index)
            return TargetField.Pick(
                value: value,
                pos: position.point,
                good: good,
                label: label,
                modifier: modifier,
                proximityFeet: proximity,
                holed: holed
            )
        }
        if entries[index].radarPositionVersion != nil { return nil }
        switch slotMode(slot) {
        case .fairway: return fairwayPlacement(value: value, modifier: modifier, good: good, label: label)
        case .green: return greenPlacement(value: value, modifier: modifier, label: label)
        case .putt: return puttPlacement(slot, at: index)
        }
    }

    private func fairwayPlacement(value: String?, modifier: String?, good: Bool, label: String) -> TargetField.Pick {
        let lat: CGFloat = value == "Fairway" ? 0 : modifier == "Bunker" ? 0.30 : 0.16
        let sign: CGFloat = value?.hasSuffix("Left") == true ? -1 : 1
        let pos = CGPoint(x: Self.placeCX + lat * sign, y: 0.30)
        return TargetField.Pick(value: value, pos: pos, good: good, label: label, modifier: modifier)
    }

    private func greenPlacement(value: String?, modifier: String?, label: String) -> TargetField.Pick {
        let cx = Self.placeCX, cy = Self.placeCY
        if value == "Green" || value == "On In 2" || value == RoundPlayState.holedShotRaw {
            let holed = value == RoundPlayState.holedShotRaw
            let pos = CGPoint(x: cx, y: cy + 0.05)
            return TargetField.Pick(value: value, pos: pos, good: true, label: label, modifier: modifier, holed: holed)
        }
        var x = cx, y = cy
        if value?.hasSuffix("Left") == true { x = cx - 0.34 }
        if value?.hasSuffix("Right") == true { x = cx + 0.34 }
        if value?.hasSuffix("Long") == true { y = cy - 0.34 }
        if value?.hasSuffix("Short") == true { y = cy + 0.34 }
        return TargetField.Pick(value: value, pos: CGPoint(x: x, y: y), good: false, label: label, modifier: modifier)
    }

    private func puttPlacement(_ slot: ShotSlot, at index: Int) -> TargetField.Pick? {
        guard case let .putt(shotIndex) = slot else { return nil }
        let cx = Self.placeCX, cy = Self.placeCY
        if isLastPutt(slot, at: index), isPuttHoled(at: index) {
            let pos = CGPoint(x: cx, y: cy)
            return TargetField.Pick(value: nil, pos: pos, good: true, label: "HOLED", proximityFeet: 0, holed: true)
        }
        let feet = entries[index].puttDistances[safe: shotIndex].flatMap { $0 } ?? 6
        let radius = min(1, CGFloat(feet) / 15) * 0.40
        let pos = CGPoint(x: cx, y: cy + radius)
        return TargetField.Pick(value: nil, pos: pos, good: false, label: "\(feet) FT", proximityFeet: feet)
    }
}
