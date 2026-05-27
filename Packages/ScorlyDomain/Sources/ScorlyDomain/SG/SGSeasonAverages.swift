import Foundation

/// Mean of per-category Strokes Gained across every round in `rounds`
/// that has SG data and is not the round identified by `id`. Returns
/// `nil` if no other round contributes — in which case the caller
/// (e.g. the Round Detail SG card) hides the ghost markers and the
/// "vs season" delta.
public func sgSeasonAverages(
    excluding id: UUID,
    from rounds: [CompletedRound]
) -> SGTotals? {
    let cohort = rounds.compactMap { round -> SGTotals? in
        guard round.id != id else { return nil }
        return round.sgTotals
    }
    guard !cohort.isEmpty else { return nil }
    let count = Decimal(cohort.count)
    var ott: Decimal = 0
    var app: Decimal = 0
    var arg: Decimal = 0
    var putt: Decimal = 0
    var total: Decimal = 0
    for totals in cohort {
        ott += totals.ott
        app += totals.app
        arg += totals.arg
        putt += totals.putt
        total += totals.total
    }
    return SGTotals(
        ott: ott / count,
        app: app / count,
        arg: arg / count,
        putt: putt / count,
        total: total / count
    )
}
