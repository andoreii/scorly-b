import Foundation

/// World Handicap System math. Uses `Decimal` throughout and rounds to one
/// decimal place at the boundary, matching the DB's `NUMERIC(4,1)` columns.
public enum WHSCalculator {
    // MARK: - Public API

    /// `(113 / slope) × (score - rating)`, rounded to one decimal.
    /// `nil` unless 18 holes with a positive rating and slope (9-hole
    /// rounds aren't WHS-eligible without a combine step we don't implement).
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

    /// Caller passes all eligible differentials, oldest first. Uses the most
    /// recent 20: full history averages the lowest 8 with a 0.96 multiplier
    /// (officially deprecated since 2024, kept for parity), 3-19 rounds use
    /// the USGA short-history table, fewer than 3 returns `nil`.
    public static func handicapIndex(from differentials: [Decimal]) -> Decimal? {
        let recent = Array(differentials.suffix(maxRoundsConsidered))
        let count = recent.count

        if count >= maxRoundsConsidered {
            return fullHistoryIndex(from: recent)
        }
        return partialHistoryIndex(from: recent)
    }

    // MARK: - Internals

    private static let maxRoundsConsidered = 20

    /// Stored as 96/100 to avoid Double-literal precision drift.
    private static let ninetySixPercent = Decimal(96) / Decimal(100)

    /// Caller has already clipped to 20.
    private static func fullHistoryIndex(from differentials: [Decimal]) -> Decimal {
        let lowest = differentials.sorted().prefix(8)
        let avg = average(of: Array(lowest))
        return roundedToOneDecimal(avg * ninetySixPercent)
    }

    /// `nil` for fewer than 3 rounds.
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

    /// Verbatim from the WHS Rules of Handicapping.
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

    /// `.plain` matches the DB column's `NUMERIC(4,1)` rounding.
    private static func roundedToOneDecimal(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal.zero
        NSDecimalRound(&output, &input, 1, .plain)
        return output
    }
}
