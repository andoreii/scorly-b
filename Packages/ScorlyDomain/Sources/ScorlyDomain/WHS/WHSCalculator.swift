import Foundation

/// World Handicap System math. Pure, decimal-precise, side-effect free.
///
/// Two operations:
/// - `differential(score:rating:slope:holesPlayed:)` — per-round score
///   differential, defined only for 18-hole rounds with a valid course
///   rating and slope.
/// - `handicapIndex(from:)` — overall handicap index from a list of
///   differentials. Uses the USGA short-history table for fewer than 20
///   rounds; for 20+ rounds, takes the most-recent 20 and averages the
///   lowest 8 with a × 0.96 multiplier.
///
/// All arithmetic uses `Decimal` to avoid binary-float drift on rounding.
/// Inputs and outputs are rounded to one decimal place at the boundary,
/// matching the precision the DB stores (`NUMERIC(4,1)`).
public enum WHSCalculator {
    // MARK: - Public API

    /// Per-round score differential.
    ///
    /// Formula: `(113 / slope) × (score − rating)`, rounded to one decimal.
    ///
    /// Returns `nil` unless **all** of:
    /// - `holesPlayed == .eighteen` (9-hole rounds aren't WHS-eligible
    ///   without a separate combine step we don't yet implement)
    /// - `rating > 0`
    /// - `slope > 0`
    public static func differential(
        score: Int,
        rating: Decimal,
        slope: Decimal,
        holesPlayed: HolesPlayed
    ) -> Decimal? {
        guard holesPlayed == .eighteen else { return nil }
        guard rating > 0 else { return nil }
        guard slope > 0 else { return nil }

        let oneThirteen = Decimal(113)
        let raw = (oneThirteen / slope) * (Decimal(score) - rating)
        return roundedToOneDecimal(raw)
    }

    /// Handicap index from a chronologically-ordered list of differentials.
    ///
    /// Caller passes **all** eligible differentials (oldest first). This
    /// function takes `suffix(20)` and applies:
    /// - **20 rounds:** average of the lowest 8, multiplied by 0.96.
    /// - **3–19 rounds:** the USGA short-history table — see
    ///   `partialHistoryRule(for:)` for the exact lowest-N + adjustment
    ///   per row.
    /// - **< 3 rounds:** `nil` (insufficient history).
    ///
    /// The 0.96 multiplier matches v1's behaviour (the WHS 96% adjustment
    /// is officially deprecated as of 2024 but v1 applied it; we keep
    /// parity until an explicit migration ticket says otherwise).
    public static func handicapIndex(from differentials: [Decimal]) -> Decimal? {
        let recent = Array(differentials.suffix(maxRoundsConsidered))
        let count = recent.count

        if count >= maxRoundsConsidered {
            return fullHistoryIndex(from: recent)
        }
        return partialHistoryIndex(from: recent)
    }

    // MARK: - Internals

    /// We never look further back than the most recent 20 rounds.
    private static let maxRoundsConsidered = 20

    /// 96% multiplier applied only to the full-history (20-round) case.
    /// Stored as 96/100 to avoid Double-literal precision drift.
    private static let ninetySixPercent = Decimal(96) / Decimal(100)

    /// Average of the lowest 8 of the supplied 20 differentials, × 0.96,
    /// rounded to one decimal. Caller has already clipped to 20.
    private static func fullHistoryIndex(from differentials: [Decimal]) -> Decimal {
        let lowest = differentials.sorted().prefix(8)
        let avg = average(of: Array(lowest))
        return roundedToOneDecimal(avg * ninetySixPercent)
    }

    /// USGA short-history index for 3–19 rounds.
    /// Returns `nil` for fewer than 3.
    private static func partialHistoryIndex(from differentials: [Decimal]) -> Decimal? {
        guard let rule = partialHistoryRule(for: differentials.count) else {
            return nil
        }
        let lowest = differentials.sorted().prefix(rule.usedCount)
        let avg = average(of: Array(lowest))
        return roundedToOneDecimal(avg - rule.adjustment)
    }

    private struct PartialHistoryRule {
        let usedCount: Int
        let adjustment: Decimal
    }

    /// USGA short-history table — verbatim from the WHS Rules of Handicapping.
    /// Counts ≤ 2 yield `nil`; counts ≥ 20 are handled by `fullHistoryIndex`.
    private static func partialHistoryRule(for count: Int) -> PartialHistoryRule? {
        switch count {
        case 3: PartialHistoryRule(usedCount: 1, adjustment: 2)
        case 4: PartialHistoryRule(usedCount: 1, adjustment: 1)
        case 5: PartialHistoryRule(usedCount: 1, adjustment: 0)
        case 6: PartialHistoryRule(usedCount: 2, adjustment: 1)
        case 7...8: PartialHistoryRule(usedCount: 2, adjustment: 0)
        case 9...11: PartialHistoryRule(usedCount: 3, adjustment: 0)
        case 12...14: PartialHistoryRule(usedCount: 4, adjustment: 0)
        case 15...16: PartialHistoryRule(usedCount: 5, adjustment: 0)
        case 17...18: PartialHistoryRule(usedCount: 6, adjustment: 0)
        case 19: PartialHistoryRule(usedCount: 7, adjustment: 0)
        default: nil
        }
    }

    private static func average(of values: [Decimal]) -> Decimal {
        guard !values.isEmpty else { return 0 }
        let sum = values.reduce(Decimal.zero, +)
        return sum / Decimal(values.count)
    }

    /// Rounds to one decimal place, banker's-rounding tied half. `.plain`
    /// matches v1's display rounding and the DB column's `NUMERIC(4,1)`
    /// scale.
    private static func roundedToOneDecimal(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal.zero
        NSDecimalRound(&output, &input, 1, .plain)
        return output
    }
}
