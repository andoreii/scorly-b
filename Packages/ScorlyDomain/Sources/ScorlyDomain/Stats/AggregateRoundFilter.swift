import Foundation

/// Shared eligibility predicate for any aggregate stat surface (Home avg,
/// History, Trends, Courses best).
///
/// An empty set on a category means "include everything for that category"
/// (including nil values); a non-empty set requires the value to be
/// present and in the set.
public struct AggregateRoundFilter: Sendable, Equatable, Codable {
    public var holesPlayed: Set<HolesPlayed>
    public var formats: Set<RoundFormat>
    public var roundTypes: Set<RoundType>
    public var teeNames: Set<String>

    public init(
        holesPlayed: Set<HolesPlayed> = [],
        formats: Set<RoundFormat> = [],
        roundTypes: Set<RoundType> = [],
        teeNames: Set<String> = []
    ) {
        self.holesPlayed = holesPlayed
        self.formats = formats
        self.roundTypes = roundTypes
        self.teeNames = teeNames
    }

    /// 18 holes, Stroke + Stableford + Match, all round types, all tees.
    public static let `default` = AggregateRoundFilter(
        holesPlayed: [.eighteen],
        formats: [.stroke, .stableford, .match],
        roundTypes: [],
        teeNames: []
    )

    public func includes(_ round: CompletedRound) -> Bool {
        aggregateFilterIncludes(
            format: round.roundFormat,
            type: round.roundType,
            holes: round.holesPlayed,
            tee: round.teeName,
            filter: self
        )
    }
}

/// Free predicate so projections without a full `CompletedRound` (e.g.
/// repository fast-path queries) can reuse the same eligibility rule.
public func aggregateFilterIncludes(
    format: RoundFormat?,
    type: RoundType?,
    holes: HolesPlayed,
    tee: String?,
    filter: AggregateRoundFilter
) -> Bool {
    if !filter.holesPlayed.isEmpty, !filter.holesPlayed.contains(holes) {
        return false
    }
    if !filter.formats.isEmpty {
        guard let format, filter.formats.contains(format) else { return false }
    }
    if !filter.roundTypes.isEmpty {
        guard let type, filter.roundTypes.contains(type) else { return false }
    }
    if !filter.teeNames.isEmpty {
        guard let tee, filter.teeNames.contains(tee) else { return false }
    }
    return true
}

public extension Sequence where Element == CompletedRound {
    /// Returns rounds matching `filter`. Preserves source order.
    func eligible(for filter: AggregateRoundFilter) -> [CompletedRound] {
        self.filter(filter.includes)
    }
}
