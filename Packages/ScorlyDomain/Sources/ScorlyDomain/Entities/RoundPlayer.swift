import Foundation

/// Snapshot of someone in the user's group for a single round, captured at
/// the time and never updated. No FK to a global player table.
public struct RoundPlayer: Sendable, Equatable, Codable {
    public let name: String
    /// Nil until the WHS index is calculated, or for guests with no entered handicap.
    public let handicap: Decimal?

    public init(name: String, handicap: Decimal? = nil) {
        self.name = name
        self.handicap = handicap
    }
}
