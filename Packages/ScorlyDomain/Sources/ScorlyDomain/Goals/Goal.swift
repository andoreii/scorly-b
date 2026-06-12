import Foundation

/// A user-set golf-improvement goal.
///
/// `id` doubles as the `goal_external_id` idempotency key on the Supabase
/// write path. `archivedAt` is a soft-delete marker; the evaluator doesn't
/// care, callers filter before passing goals in.
public struct Goal: Sendable, Equatable, Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let kind: GoalKind
    public let createdAt: Date
    public let deadline: Date?
    public let archivedAt: Date?

    public init(
        id: UUID,
        title: String,
        kind: GoalKind,
        createdAt: Date,
        deadline: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.createdAt = createdAt
        self.deadline = deadline
        self.archivedAt = archivedAt
    }
}

/// What a `Goal` measures and how. The associated value is the target
/// threshold. Direction is encoded in the case name (`AtLeast`/`OrEqual`
/// = achieved when current >= target; `AtMost`/`BelowOrEqual` = <= target).
/// Decimal targets are rates in `0...1` for `*Rate*` cases, SG values otherwise.
public enum GoalKind: Sendable, Equatable, Codable {
    /// Best round score achieves at-or-below `target`.
    case scoreUnderOrEqual(target: Int)
    /// Computed handicap index drops to at-or-below `target`.
    case handicapBelowOrEqual(target: Decimal)
    /// Aggregate GIR rate (greens / holes) reaches `target` (0...1).
    case girRateAtLeast(target: Decimal)
    /// Aggregate FIR rate (fairways / par-4+ holes) reaches `target`.
    case firRateAtLeast(target: Decimal)
    /// Aggregate 3-putt rate (3-putts / holes) drops to at-or-below `target`.
    case threePuttRateAtMost(target: Decimal)
    /// Average per-round SG in the chosen category reaches `target`.
    case sgCategoryAtLeast(category: SGCategory, target: Decimal)
    /// Total rounds played reaches `target`.
    case roundsPlayed(target: Int)
}

/// Snapshot of how close a goal is to being achieved. `fraction` is
/// normalized to `0...1` for progress bars (for `*AtMost` goals it
/// inverts: shrinking `current` grows `fraction` toward 1).
public struct GoalProgress: Sendable, Equatable {
    public let current: Decimal
    public let target: Decimal
    public let isAchieved: Bool
    public let fraction: Decimal

    public init(current: Decimal, target: Decimal, isAchieved: Bool, fraction: Decimal) {
        self.current = current
        self.target = target
        self.isAchieved = isAchieved
        self.fraction = fraction
    }
}
