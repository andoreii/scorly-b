import Foundation

/// A user-set golf-improvement goal.
///
/// `id` is a client-generated UUID — also the `goal_external_id`
/// idempotency key on the Supabase write path (Phase C5).
///
/// `kind` carries the actual measurement target via an enum-with-
/// associated-values; this keeps everything that defines a goal type
/// (target value, comparison direction, evaluation rules) co-located in
/// `GoalKind` and `GoalEvaluator`.
///
/// `archivedAt` is a soft-delete marker. Callers can present an
/// "archived" view; the evaluator doesn't care — feed it any subset of
/// goals you want progress for.
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

/// What a `Goal` measures and how. The associated value on each case is
/// the **target threshold** the player wants to reach.
///
/// Direction (≤ vs ≥) is encoded in the case name so it's impossible to
/// confuse "GIR rate at least 0.5" with "GIR rate at most 0.5":
/// - `*AtLeast` / `*OrEqual` (where "OrEqual" implies the natural direction)
///   → goal is achieved when current value ≥ target.
/// - `*AtMost` / `BelowOrEqual` → goal is achieved when current value ≤ target.
///
/// All Decimal targets are rates in `0...1` for `*Rate*` cases (e.g.
/// `girRateAtLeast(target: 0.6)` = 60% GIR), and SG values for SG cases.
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

/// Snapshot of how close a goal is to being achieved.
///
/// `current` and `target` use the same units as the underlying metric (an
/// Int score, a 0...1 rate, a Decimal SG value). `fraction` is normalized
/// to `0...1` for UI progress bars: 0 = no progress, 1 = achieved.
///
/// For `*AtMost` / `*BelowOrEqual` goals the fraction inverts: as
/// `current` shrinks toward 0, `fraction` grows toward 1.
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
