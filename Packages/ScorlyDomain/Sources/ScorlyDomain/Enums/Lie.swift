import Foundation

/// Where a shot landed, normalized for Strokes Gained categorization
/// (Fairway / Rough / Sand / Recovery / Green). RawValue strings stay
/// backwards-compatible with the legacy shot-location encoding; see Mappings.swift.
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
