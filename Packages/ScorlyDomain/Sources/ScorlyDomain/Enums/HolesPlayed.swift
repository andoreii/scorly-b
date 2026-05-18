import Foundation

/// Whether the round covered the front nine, back nine, or full eighteen.
///
/// Persisted as a string in `rounds.holes_played`. The raw values match
/// v1's DB-canonical labels exactly so historical rounds decode cleanly.
public enum HolesPlayed: String, Codable, CaseIterable, Hashable, Sendable {
    case front9 = "Front 9"
    case back9 = "Back 9"
    case eighteen = "18"

    /// Number of holes the round covers.
    public var holeCount: Int {
        switch self {
        case .front9, .back9: 9
        case .eighteen: 18
        }
    }

    /// Hole numbers, in the order they were played.
    public var holeNumbers: [Int] {
        switch self {
        case .front9: Array(1...9)
        case .back9: Array(10...18)
        case .eighteen: Array(1...18)
        }
    }
}
