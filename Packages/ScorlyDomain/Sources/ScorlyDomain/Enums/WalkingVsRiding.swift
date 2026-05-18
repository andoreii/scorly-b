import Foundation

/// How the player got around the course. Persisted in `rounds.walking_vs_riding`.
public enum WalkingVsRiding: String, Codable, CaseIterable, Hashable, Sendable {
    case walking = "Walking"
    case riding = "Riding"
    case pushCart = "Push Cart"
    case mixed = "Mixed"
}
