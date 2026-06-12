import Foundation

/// Game format played. Persisted in `rounds.round_format`. Stableford is
/// now its own case; older rows that stored it as "Other" still decode fine.
public enum RoundFormat: String, Codable, CaseIterable, Hashable, Sendable {
    case stroke = "Stroke"
    case match = "Match"
    case scramble = "Scramble"
    case stableford = "Stableford"
    case other = "Other"
}
