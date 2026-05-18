import Foundation

/// Generates `Insight` cards from a set of `CompletedRound`s.
///
/// Single entry point: `weeklyInsights(from:referenceDate:)`.
/// "Weekly" means the function filters input rounds to those played in
/// the 7 days **strictly before** `referenceDate` (inclusive of
/// `referenceDate` itself). Rounds outside that window — and rounds
/// without `sgTotals` — are ignored.
///
/// Output ordering (when present):
/// 1. Up to 3 weaknesses (most-negative average SG first).
/// 2. Up to 1 strength (most-positive average SG, if positive).
/// 3. Up to 1 practice focus (= the single worst weakness).
///
/// All three sections may be empty: no recent rounds → empty array;
/// every category positive → no weaknesses or practice focus; every
/// category negative → no strength.
public enum InsightEngine {
    /// 7 days expressed in seconds — used for the rolling-week window.
    private static let weekSeconds: TimeInterval = 7 * 24 * 60 * 60

    public static func weeklyInsights(
        from rounds: [CompletedRound],
        referenceDate: Date = Date()
    ) -> [Insight] {
        let weekStart = referenceDate.addingTimeInterval(-weekSeconds)
        let recentTotals = rounds
            .filter { $0.datePlayed > weekStart && $0.datePlayed <= referenceDate }
            .compactMap(\.sgTotals)
        guard !recentTotals.isEmpty else { return [] }

        let count = Decimal(recentTotals.count)
        let averages: [(category: SGCategory, avg: Decimal)] = SGCategory.allCases.map { category in
            let sum = recentTotals.reduce(Decimal(0)) { $0 + $1.value(for: category) }
            return (category, sum / count)
        }

        let ascending = averages.sorted { $0.avg < $1.avg }

        let weaknesses = ascending
            .prefix(3)
            .filter { $0.avg < 0 }
            .map { Insight(kind: .weakness, category: $0.category, avgPerRound: $0.avg) }

        var result: [Insight] = weaknesses

        if let strongest = averages.max(by: { $0.avg < $1.avg }), strongest.avg > 0 {
            result.append(Insight(kind: .strength, category: strongest.category, avgPerRound: strongest.avg))
        }

        if let worst = ascending.first, worst.avg < 0 {
            result.append(Insight(kind: .practiceFocus, category: worst.category, avgPerRound: worst.avg))
        }

        return result
    }
}
