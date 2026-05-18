import Foundation

/// Pure evaluation of a `Goal` against a list of `CompletedRound`s.
///
/// Each `GoalKind` has a "current value" computed from the round set
/// (best score, aggregate rate, average SG, etc.) and a comparison
/// against the target. The result is packed into `GoalProgress`.
///
/// **No round filtering happens here.** Caller decides which rounds are
/// in scope (e.g. "rounds since the goal was created", "last 90 days").
/// Empty or all-nil-data round sets return `current = 0`, `fraction = 0`,
/// `isAchieved = false`.
public enum GoalEvaluator {
    public static func evaluate(goal: Goal, against rounds: [CompletedRound]) -> GoalProgress {
        switch goal.kind {
        case let .scoreUnderOrEqual(target):
            return evaluateScoreUnder(target: target, rounds: rounds)
        case let .handicapBelowOrEqual(target):
            return evaluateHandicap(target: target, rounds: rounds)
        case let .girRateAtLeast(target):
            return evaluateGirRate(target: target, rounds: rounds)
        case let .firRateAtLeast(target):
            return evaluateFirRate(target: target, rounds: rounds)
        case let .threePuttRateAtMost(target):
            return evaluateThreePuttRate(target: target, rounds: rounds)
        case let .sgCategoryAtLeast(category, target):
            return evaluateSGCategory(category: category, target: target, rounds: rounds)
        case let .roundsPlayed(target):
            return evaluateRoundsPlayed(target: target, rounds: rounds)
        }
    }

    // MARK: - Per-kind evaluators

    private static func evaluateScoreUnder(target: Int, rounds: [CompletedRound]) -> GoalProgress {
        let target = Decimal(target)
        guard let best = rounds.map(\.totalScore).min() else {
            return zero(target: target)
        }
        let current = Decimal(best)
        return atMost(current: current, target: target)
    }

    private static func evaluateHandicap(target: Decimal, rounds: [CompletedRound]) -> GoalProgress {
        let diffs = rounds.compactMap(\.differential)
        guard let index = WHSCalculator.handicapIndex(from: diffs) else {
            return zero(target: target)
        }
        return atMost(current: index, target: target)
    }

    private static func evaluateGirRate(target: Decimal, rounds: [CompletedRound]) -> GoalProgress {
        let totalGir = rounds.reduce(0) { $0 + $1.girCount }
        let totalHoles = rounds.reduce(0) { $0 + $1.holeStats.count }
        guard totalHoles > 0 else { return zero(target: target) }
        let rate = Decimal(totalGir) / Decimal(totalHoles)
        return atLeast(current: rate, target: target)
    }

    private static func evaluateFirRate(target: Decimal, rounds: [CompletedRound]) -> GoalProgress {
        let totalFir = rounds.reduce(0) { $0 + $1.firCount }
        let totalOpps = rounds.reduce(0) { $0 + $1.firOpportunities }
        guard totalOpps > 0 else { return zero(target: target) }
        let rate = Decimal(totalFir) / Decimal(totalOpps)
        return atLeast(current: rate, target: target)
    }

    private static func evaluateThreePuttRate(target: Decimal, rounds: [CompletedRound]) -> GoalProgress {
        let total3p = rounds.reduce(0) { $0 + $1.threePuttCount }
        let totalHoles = rounds.reduce(0) { $0 + $1.holeStats.count }
        guard totalHoles > 0 else { return zero(target: target) }
        let rate = Decimal(total3p) / Decimal(totalHoles)
        return atMost(current: rate, target: target)
    }

    private static func evaluateSGCategory(
        category: SGCategory,
        target: Decimal,
        rounds: [CompletedRound]
    ) -> GoalProgress {
        let totals = rounds.compactMap(\.sgTotals)
        guard !totals.isEmpty else { return zero(target: target) }
        let sum = totals.reduce(Decimal(0)) { $0 + $1.value(for: category) }
        let avg = sum / Decimal(totals.count)
        return atLeast(current: avg, target: target)
    }

    private static func evaluateRoundsPlayed(target: Int, rounds: [CompletedRound]) -> GoalProgress {
        let target = Decimal(target)
        let count = Decimal(rounds.count)
        return atLeast(current: count, target: target)
    }

    // MARK: - Direction helpers

    /// Progress for an "at least" goal: `current ≥ target`.
    /// Fraction is `current / target`, capped at 1.
    private static func atLeast(current: Decimal, target: Decimal) -> GoalProgress {
        let achieved = current >= target
        let fraction: Decimal
        if achieved {
            fraction = 1
        } else if target > 0 {
            fraction = max(0, min(current / target, 1))
        } else {
            // target ≤ 0 with current < target is degenerate; report 0.
            fraction = 0
        }
        return GoalProgress(current: current, target: target, isAchieved: achieved, fraction: fraction)
    }

    /// Progress for an "at most" goal: `current ≤ target`.
    /// Fraction inverts: as `current` shrinks toward `target`, fraction
    /// grows toward 1. Computed as `target / current` while above target.
    private static func atMost(current: Decimal, target: Decimal) -> GoalProgress {
        let achieved = current <= target
        let fraction: Decimal
        if achieved {
            fraction = 1
        } else if current > 0 {
            fraction = max(0, min(target / current, 1))
        } else {
            fraction = 1
        }
        return GoalProgress(current: current, target: target, isAchieved: achieved, fraction: fraction)
    }

    private static func zero(target: Decimal) -> GoalProgress {
        GoalProgress(current: 0, target: target, isAchieved: false, fraction: 0)
    }
}
