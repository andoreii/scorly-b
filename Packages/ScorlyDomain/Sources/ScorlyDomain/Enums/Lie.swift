import Foundation

/// Where a shot landed, normalized for Strokes Gained categorization.
///
/// Derived from v1's free-form shot-location enum. v1 stored the raw label
/// as TEXT in `hole_stats.tee_shot` / `hole_stats.approach`. v2 keeps the
/// rawValue strings backwards-compatible with that historical data.
///
/// The 12 cases collapse v1's 14-value shot-location enum into a smaller
/// set aligned with Mark Broadie's 5 SG benchmark categories
/// (Fairway / Rough / Sand / Recovery / Green). The v1 → v2 mapping lives
/// in `Mappings.swift` (Phase B2).
public enum Lie: String, Codable, CaseIterable, Hashable, Sendable {
    case fairway = "Fairway"
    case roughLeft = "Rough Left"
    case roughRight = "Rough Right"
    case bunkerLeft = "Bunker Left"
    case bunkerRight = "Bunker Right"
    case bunkerShort = "Bunker Short"
    case bunkerLong = "Bunker Long"
    case recoveryLeft = "Recovery Left"
    case recoveryRight = "Recovery Right"
    case recoveryShort = "Recovery Short"
    case recoveryLong = "Recovery Long"
    case green = "Green"
}
