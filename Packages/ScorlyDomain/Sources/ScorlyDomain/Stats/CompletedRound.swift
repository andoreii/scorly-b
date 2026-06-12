import Foundation

/// A finished round, in the shape goals + insights need to evaluate it.
/// `sgTotals` is nil when shot distances weren't recorded; goals/insights relying on SG skip those rounds.
public struct CompletedRound: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let datePlayed: Date
    public let par: Int
    public let totalScore: Int
    public let holesPlayed: HolesPlayed
    public let courseRating: Decimal?
    public let slope: Decimal?
    public let holeStats: [HoleStat]
    public let sgTotals: SGTotals?
    /// Per-hole SG breakdown, parallel-indexed with `holeStats`; nil iff `sgTotals` is nil.
    public let sgHoles: [SGTotals]?
    public let roundType: RoundType?
    public let roundFormat: RoundFormat?
    public let conditions: Conditions
    public let courseName: String?
    public let courseExternalId: UUID?
    public let teeName: String?
    public let teeCategory: TeeCategory?
    public let walkingVsRiding: WalkingVsRiding?

    public init(
        id: UUID,
        datePlayed: Date,
        par: Int,
        totalScore: Int,
        holesPlayed: HolesPlayed,
        courseRating: Decimal? = nil,
        slope: Decimal? = nil,
        holeStats: [HoleStat] = [],
        sgTotals: SGTotals? = nil,
        sgHoles: [SGTotals]? = nil,
        roundType: RoundType? = nil,
        roundFormat: RoundFormat? = nil,
        conditions: Conditions = [],
        courseName: String? = nil,
        courseExternalId: UUID? = nil,
        teeName: String? = nil,
        teeCategory: TeeCategory? = nil,
        walkingVsRiding: WalkingVsRiding? = nil
    ) {
        self.id = id
        self.datePlayed = datePlayed
        self.par = par
        self.totalScore = totalScore
        self.holesPlayed = holesPlayed
        self.courseRating = courseRating
        self.slope = slope
        self.holeStats = holeStats
        self.sgTotals = sgTotals
        self.sgHoles = sgHoles
        self.roundType = roundType
        self.roundFormat = roundFormat
        self.conditions = conditions
        self.courseName = courseName
        self.courseExternalId = courseExternalId
        self.teeName = teeName
        self.teeCategory = teeCategory
        self.walkingVsRiding = walkingVsRiding
    }

    // MARK: - Derived

    /// WHS score differential, or nil if not WHS-eligible (not 18 holes, missing rating/slope).
    public var differential: Decimal? {
        guard let rating = courseRating, let slope else { return nil }
        return WHSCalculator.differential(
            score: totalScore,
            rating: rating,
            slope: slope,
            holesPlayed: holesPlayed
        )
    }

    /// Total strokes minus total par. Negative = under par.
    public var scoreVsPar: Int {
        totalScore - par
    }

    /// Greens-in-regulation count over `holeStats`.
    public var girCount: Int {
        holeStats.lazy.filter(\.greenInRegulation).count
    }

    /// Fairways-in-regulation count over `holeStats`.
    public var firCount: Int {
        holeStats.lazy.filter(\.fairwayInRegulation).count
    }

    /// Denominator for FIR rate: holes where FIR is applicable (par 4+).
    public var firOpportunities: Int {
        holeStats.lazy.filter { $0.par >= 4 }.count
    }

    /// Number of holes with 3 or more putts.
    public var threePuttCount: Int {
        holeStats.lazy.filter(\.threePutt).count
    }

    /// Sum of `putts` across all hole stats.
    public var totalPutts: Int {
        holeStats.reduce(0) { $0 + $1.putts }
    }
}
