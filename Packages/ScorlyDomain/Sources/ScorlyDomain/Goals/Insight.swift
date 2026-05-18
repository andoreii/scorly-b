import Foundation

/// One observation about the player's recent performance, ready to be
/// rendered as a card on the Trends or Goals tab.
///
/// Carries just the data the UI needs (kind + category + magnitude); the
/// view layer is responsible for any human-readable copy.
public struct Insight: Sendable, Equatable {
    public let kind: InsightKind
    public let category: SGCategory
    /// The signed average per-round Strokes Gained for this category over
    /// the input window. Negative = below scratch baseline.
    public let avgPerRound: Decimal

    public init(kind: InsightKind, category: SGCategory, avgPerRound: Decimal) {
        self.kind = kind
        self.category = category
        self.avgPerRound = avgPerRound
    }
}

public enum InsightKind: Sendable, Equatable {
    /// A category where the player is losing strokes (negative avg SG).
    case weakness
    /// The category where the player is gaining the most strokes.
    case strength
    /// Suggested area to practise — the worst weakness, surfaced
    /// separately so the UI can show a single dedicated CTA.
    case practiceFocus
}
