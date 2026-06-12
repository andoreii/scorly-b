import Foundation

/// Reference point used when presenting canonical scratch-relative SG.
/// Storage remains scratch-relative; personal average is a view-time
/// projection over the latest SG-enabled rounds.
public enum SGComparisonReference: String, Codable, CaseIterable, Sendable {
    case scratch
    case personalAverage

    public static let userDefaultsKey = "com.scorly.sgComparisonReference"

    public var settingsLabel: String {
        switch self {
        case .scratch: "SCRATCH"
        case .personalAverage: "PERSONAL AVG"
        }
    }

    public var referenceLabel: String {
        "VS \(settingsLabel)"
    }
}

/// Presentation-ready SG values for the selected reference point. Falls
/// back to scratch when personal history is unavailable.
public struct SGReferenceProjection: Sendable, Equatable {
    public let activeReference: SGComparisonReference
    public let totals: SGTotals?
    public let holes: [SGTotals]?

    public var referenceLabel: String {
        activeReference.referenceLabel
    }

    public static func project(
        reference: SGComparisonReference,
        totals: SGTotals?,
        holes: [SGTotals]?,
        baselineRounds: [CompletedRound]
    ) -> Self {
        guard reference == .personalAverage,
              let baseline = personalBaseline(from: baselineRounds)
        else {
            return Self(activeReference: .scratch, totals: totals, holes: holes)
        }

        return Self(
            activeReference: .personalAverage,
            totals: totals.map { subtract($0, baseline) },
            holes: holes.map { recenterHoles($0, baseline: baseline) }
        )
    }

    /// Latest 20 SG-enabled rounds, newest first after sorting.
    public static func personalBaseline(from rounds: [CompletedRound]) -> SGTotals? {
        let totals = rounds
            .sorted { $0.datePlayed > $1.datePlayed }
            .compactMap(\.sgTotals)
            .prefix(20)
        guard !totals.isEmpty else { return nil }

        let sum = totals.reduce(into: zero) { result, totals in
            result = add(result, totals)
        }
        return divide(sum, by: Decimal(totals.count))
    }

    private static func recenterHoles(_ holes: [SGTotals], baseline: SGTotals) -> [SGTotals] {
        guard !holes.isEmpty else { return [] }
        let count = Decimal(holes.count)
        let evenShare = divide(baseline, by: count)
        let priorShares = multiply(evenShare, by: Decimal(holes.count - 1))

        return holes.enumerated().map { index, hole in
            let share = index == holes.count - 1
                ? subtract(baseline, priorShares)
                : evenShare
            return subtract(hole, share)
        }
    }

    private static let zero = SGTotals(ott: 0, app: 0, arg: 0, putt: 0, total: 0)

    private static func add(_ lhs: SGTotals, _ rhs: SGTotals) -> SGTotals {
        make(
            ott: lhs.ott + rhs.ott,
            app: lhs.app + rhs.app,
            arg: lhs.arg + rhs.arg,
            putt: lhs.putt + rhs.putt
        )
    }

    private static func subtract(_ lhs: SGTotals, _ rhs: SGTotals) -> SGTotals {
        make(
            ott: lhs.ott - rhs.ott,
            app: lhs.app - rhs.app,
            arg: lhs.arg - rhs.arg,
            putt: lhs.putt - rhs.putt
        )
    }

    private static func divide(_ totals: SGTotals, by divisor: Decimal) -> SGTotals {
        make(
            ott: totals.ott / divisor,
            app: totals.app / divisor,
            arg: totals.arg / divisor,
            putt: totals.putt / divisor
        )
    }

    private static func multiply(_ totals: SGTotals, by multiplier: Decimal) -> SGTotals {
        make(
            ott: totals.ott * multiplier,
            app: totals.app * multiplier,
            arg: totals.arg * multiplier,
            putt: totals.putt * multiplier
        )
    }

    private static func make(ott: Decimal, app: Decimal, arg: Decimal, putt: Decimal) -> SGTotals {
        SGTotals(ott: ott, app: app, arg: arg, putt: putt, total: ott + app + arg + putt)
    }
}
