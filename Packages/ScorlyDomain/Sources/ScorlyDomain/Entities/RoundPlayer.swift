import Foundation

/// Snapshot of someone in the user's group for a single round. Captured at
/// the time of the round and never updated — if "John" plays a second round,
/// a fresh `RoundPlayer` is created. No FK to a global player table; this is
/// deliberately just the name + handicap the user typed in setup.
public struct RoundPlayer: Sendable, Equatable, Codable {
    public let name: String
    public let handicap: Decimal

    public init(name: String, handicap: Decimal) {
        self.name = name
        self.handicap = handicap
    }
}
