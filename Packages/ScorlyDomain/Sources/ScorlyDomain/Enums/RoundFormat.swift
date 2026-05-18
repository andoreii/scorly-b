import Foundation

/// Game format played. Persisted in `rounds.round_format`.
///
/// Note: v1's UI offered "Stableford" as a label, which the v1 DB stored
/// as `Other`. v2 promotes it to a DB-canonical value so the rounds filter
/// can target it directly; rounds written by v1 that used the alias remain
/// readable as `.other` since the rawValue match still wins.
public enum RoundFormat: String, Codable, CaseIterable, Hashable, Sendable {
    case stroke = "Stroke"
    case match = "Match"
    case scramble = "Scramble"
    case stableford = "Stableford"
    case other = "Other"
}
