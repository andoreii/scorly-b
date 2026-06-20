import ScorlyDesignSystem
import ScorlyDomain

/// Aggregate per-round metrics shared between Sign & File (in-progress
/// round about to be filed) and Round Detail (filed round in History).
/// Sits in a feature-shared package because it maps Domain `HoleStat`
/// onto DesignSystem value types — neither side of the boundary can
/// own this without breaking the `ArchitectureTests` invariant that DS
/// stays Domain-free.
public struct RoundDetailMetrics {
    public let playedHoleCount: Int
    public let scoreToPar: Int
    public let totalPutts: Int
    public let averagePuttsPerHole: Double?
    public let puttingAverageProfile: [PuttingAveragePoint]
    public let puttDistribution: PuttDistributionValues
    public let fairwayRose: AccuracyRoseValues
    public let greenRose: AccuracyRoseValues
    public let puttMakeStats: [PuttDistanceBucket: PuttMakeValues]
    public let outcomes: [ScoringOutcome: Int]
    public let scorecardGroups: [ScorecardGroupValues]

    public init(round: CompletedRound) {
        self.init(holeStats: round.holeStats, holesPlayed: round.holesPlayed)
    }

    /// Build metrics directly from raw hole stats — used by Sign & File,
    /// which has `[HoleStat]` from `RoundPlayState.derivedStat(for:)`
    /// but no `CompletedRound` until the save actually happens.
    public init(holeStats: [HoleStat], holesPlayed: HolesPlayed) {
        let played = holeStats.filter { $0.strokes > 0 }
        playedHoleCount = played.count
        scoreToPar = played.reduce(0) { $0 + $1.strokes - $1.par }
        totalPutts = played.reduce(0) { $0 + $1.putts }
        averagePuttsPerHole = played.isEmpty
            ? nil
            : Double(totalPutts) / Double(played.count)
        puttingAverageProfile = Self.puttingAverageProfile(from: holeStats, holesPlayed: holesPlayed)
        puttDistribution = Self.puttDistribution(from: played)
        fairwayRose = Self.fairwayRose(from: played)
        greenRose = Self.greenRose(from: played)
        puttMakeStats = Self.puttStats(from: played)
        outcomes = Self.outcomes(from: played)
        scorecardGroups = Self.scorecardGroups(stats: holeStats, holesPlayed: holesPlayed)
    }

    private static func puttingAverageProfile(
        from holes: [HoleStat],
        holesPlayed: HolesPlayed
    ) -> [PuttingAveragePoint] {
        var totalPutts = 0
        var playedHoles = 0
        return holes.enumerated().compactMap { index, hole in
            guard hole.strokes > 0 else { return nil }
            totalPutts += hole.putts
            playedHoles += 1
            return PuttingAveragePoint(
                holeNumber: printedHoleNumber(index: index, holesPlayed: holesPlayed, count: holes.count),
                averagePuttsPerHole: Double(totalPutts) / Double(playedHoles)
            )
        }
    }

    private static func puttDistribution(from holes: [HoleStat]) -> PuttDistributionValues {
        var onePutt = 0
        var twoPutt = 0
        var threePuttPlus = 0
        for hole in holes {
            switch hole.putts {
            case 1: onePutt += 1
            case 2: twoPutt += 1
            case 3...: threePuttPlus += 1
            default: break
            }
        }
        return PuttDistributionValues(
            onePutt: onePutt,
            twoPutt: twoPutt,
            threePuttPlus: threePuttPlus
        )
    }

    private static func fairwayRose(from holes: [HoleStat]) -> AccuracyRoseValues {
        var directions: [AccuracyRoseValues.Direction: AccuracyRoseValues.DirectionStack] = [:]
        let opportunities = holes.filter(\.fairwayOpportunity)
        let hits = opportunities.filter(\.fairwayInRegulation).count

        for hole in opportunities where !hole.fairwayInRegulation {
            let direction = roseDirection(for: hole.teeShotLie) ?? .left
            var stack = directions[direction] ?? .init()
            addLie(hole.teeShotLie, to: &stack)
            stack.ob += hole.outOfBoundsCount
            stack.water += hole.hazardCount
            directions[direction] = stack
        }

        return .init(
            hitRate: opportunities.isEmpty ? nil : Double(hits) / Double(opportunities.count),
            opportunities: opportunities.count,
            totalMisses: opportunities.count - hits,
            byDirection: directions
        )
    }

    private static func greenRose(from holes: [HoleStat]) -> AccuracyRoseValues {
        var directions: [AccuracyRoseValues.Direction: AccuracyRoseValues.DirectionStack] = [:]
        let hits = holes.filter(\.greenInRegulation).count

        for hole in holes where !hole.greenInRegulation {
            let missLie = hole.par == 3 ? hole.teeShotLie : hole.approachLie
            let direction = roseDirection(for: missLie) ?? .short
            var stack = directions[direction] ?? .init()
            addLie(missLie, to: &stack)
            stack.ob += directionalOB(hole, direction: direction)
            stack.water += directionalHazard(hole, direction: direction)
            directions[direction] = stack
        }

        return .init(
            hitRate: holes.isEmpty ? nil : Double(hits) / Double(holes.count),
            opportunities: holes.count,
            totalMisses: holes.count - hits,
            byDirection: directions
        )
    }

    private static func puttStats(from holes: [HoleStat]) -> [PuttDistanceBucket: PuttMakeValues] {
        var tallies: [PuttDistanceBucket: (made: Int, attempted: Int)] = [:]
        for distances in holes.compactMap(\.puttDistances) where !distances.isEmpty {
            for (index, distance) in distances.enumerated() {
                let bucket = PuttDistanceBucket.bucket(forFeet: distance)
                var tally = tallies[bucket] ?? (0, 0)
                tally.attempted += 1
                if index == distances.count - 1 {
                    tally.made += 1
                }
                tallies[bucket] = tally
            }
        }
        return tallies.mapValues { PuttMakeValues(made: $0.made, attempted: $0.attempted) }
    }

    private static func outcomes(from holes: [HoleStat]) -> [ScoringOutcome: Int] {
        holes.reduce(into: [:]) { result, hole in
            result[ScoringOutcome.outcome(forVsPar: hole.strokes - hole.par), default: 0] += 1
        }
    }

    private static func scorecardGroups(
        stats: [HoleStat],
        holesPlayed: HolesPlayed
    ) -> [ScorecardGroupValues] {
        let values = stats.enumerated().map { index, hole in
            ScorecardHoleValues(
                number: printedHoleNumber(index: index, holesPlayed: holesPlayed, count: stats.count),
                par: hole.par,
                strokes: hole.strokes > 0 ? hole.strokes : nil
            )
        }
        guard holesPlayed == .eighteen, values.count > 9 else {
            return [ScorecardGroupValues(label: "HOLES", holes: values)]
        }
        return [
            ScorecardGroupValues(label: "FRONT NINE", holes: Array(values.prefix(9))),
            ScorecardGroupValues(label: "BACK NINE", holes: Array(values.dropFirst(9).prefix(9))),
        ]
    }

    private static func printedHoleNumber(index: Int, holesPlayed: HolesPlayed, count: Int) -> Int {
        holesPlayed == .back9 && count <= 9 ? index + 10 : index + 1
    }

    private static func roseDirection(for lie: Lie?) -> AccuracyRoseValues.Direction? {
        switch lie {
        case .roughLeft, .bunkerLeft, .recoveryLeft: .left
        case .roughRight, .bunkerRight, .recoveryRight: .right
        case .bunkerLong, .recoveryLong: .long
        case .bunkerShort, .recoveryShort: .short
        case .fairway, .green, .none: nil
        }
    }

    private static func addLie(_ lie: Lie?, to stack: inout AccuracyRoseValues.DirectionStack) {
        switch lie {
        case .bunkerLeft, .bunkerRight, .bunkerShort, .bunkerLong:
            stack.bunker += 1
        default:
            stack.clean += 1
        }
    }

    private static func directionalOB(_ hole: HoleStat, direction: AccuracyRoseValues.Direction) -> Int {
        let directionalTotal = hole.outOfBoundsLeft + hole.outOfBoundsRight
            + hole.outOfBoundsLong + hole.outOfBoundsShort
        guard directionalTotal > 0 else { return hole.outOfBoundsCount }
        return switch direction {
        case .left: hole.outOfBoundsLeft
        case .right: hole.outOfBoundsRight
        case .long: hole.outOfBoundsLong
        case .short: hole.outOfBoundsShort
        }
    }

    private static func directionalHazard(_ hole: HoleStat, direction: AccuracyRoseValues.Direction) -> Int {
        let directionalTotal = hole.hazardLeft + hole.hazardRight + hole.hazardLong + hole.hazardShort
        guard directionalTotal > 0 else { return hole.hazardCount }
        return switch direction {
        case .left: hole.hazardLeft
        case .right: hole.hazardRight
        case .long: hole.hazardLong
        case .short: hole.hazardShort
        }
    }
}
