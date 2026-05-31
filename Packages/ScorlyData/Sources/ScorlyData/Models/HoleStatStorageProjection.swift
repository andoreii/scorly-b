import ScorlyDomain

/// Database-facing projection for a completed hole stat. The domain
/// keeps playable lies separate from penalty events; Supabase retains
/// the legacy shot-location columns, so writes fold those values back
/// together at this boundary.
struct HoleStatStorageProjection {
    let teeShot: String?
    let approach: String?
    let teeClub: String?
    let approachClub: String?
    let penaltyStrokes: Int

    init(_ stat: HoleStat) {
        penaltyStrokes = stat.effectivePenaltyStrokes

        if stat.par == 3 {
            teeShot = nil
            approach = Self.shotLocation(
                lie: stat.teeShotLie,
                penalty: stat.penaltyEvents.first { $0.phase == .approach }
            )
            teeClub = nil
            approachClub = stat.approachClub
        } else {
            teeShot = Self.shotLocation(
                lie: stat.teeShotLie,
                penalty: stat.penaltyEvents.first { $0.phase == .tee }
            )
            approach = Self.shotLocation(
                lie: stat.approachLie,
                penalty: stat.penaltyEvents.first { $0.phase == .approach }
            )
            teeClub = stat.teeClub
            approachClub = stat.approachClub
        }
    }

    private static func shotLocation(lie: Lie?, penalty: PenaltyEvent?) -> String? {
        guard let penalty else {
            return Mappings.v1ShotLocation(for: lie)
        }
        guard let direction = penalty.direction else { return nil }
        let label = direction.rawValue.capitalized
        switch penalty.kind {
        case .outOfBounds:
            return "Out \(label)"
        case .hazard:
            return direction == .long ? "\(label) Water" : "\(label) water"
        }
    }
}
