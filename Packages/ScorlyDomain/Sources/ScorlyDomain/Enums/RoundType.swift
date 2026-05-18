import Foundation

/// Why the round was played. Persisted in `rounds.round_type`.
public enum RoundType: String, Codable, CaseIterable, Hashable, Sendable {
    case practice = "Practice"
    case tournament = "Tournament"
    case casual = "Casual"
    /// Competitive club or society round, distinct from a formal tournament.
    /// Added in v2; historical rounds stored as "Tournament" in the DB are
    /// not migrated.
    case competitive = "Competitive"
}
