import Foundation
import ScorlyDomain

// Pure aggregates the Trend-page carousels need on top of `TrendsModel`.
// Computed from a filtered, chronologically ordered `[CompletedRound]`.

// MARK: - Wind rose

/// Counts grouped by miss direction (left / right / long / short) and
/// severity (clean / bunker / water / OB). Percentages are derived from
/// the total miss count, not total holes — the center bubble carries
/// the hit-rate separately.
public struct WindRoseData: Sendable, Equatable {
    /// Per-direction breakdown of miss severity.
    public struct DirectionStack: Sendable, Equatable, Hashable {
        public var clean: Int
        public var bunker: Int
        public var water: Int
        public var ob: Int
        public init(clean: Int = 0, bunker: Int = 0, water: Int = 0, ob: Int = 0) {
            self.clean = clean
            self.bunker = bunker
            self.water = water
            self.ob = ob
        }

        public var total: Int {
            clean + bunker + water + ob
        }
    }

    public enum Direction: String, CaseIterable, Sendable {
        case left, right, long, short
    }

    /// Hit rate (FIR or GIR) over the window. `nil` when the window
    /// produced no opportunities (par-3-only fairway query, etc.).
    public let hitRate: Double?
    /// Total opportunities (denominator) across the window.
    public let opportunities: Int
    /// Total misses (sum of stacks across all four directions).
    public let totalMisses: Int
    /// Stack of miss severity per direction.
    public let byDirection: [Direction: DirectionStack]

    public init(
        hitRate: Double?,
        opportunities: Int,
        totalMisses: Int,
        byDirection: [Direction: DirectionStack]
    ) {
        self.hitRate = hitRate
        self.opportunities = opportunities
        self.totalMisses = totalMisses
        self.byDirection = byDirection
    }

    public static let empty = Self(
        hitRate: nil,
        opportunities: 0,
        totalMisses: 0,
        byDirection: [:]
    )

    /// Petal length normalized to `[0, 1]` against the loudest petal.
    /// Used by the chart to scale petals against the rose radius.
    public func petalLength(for direction: Direction) -> Double {
        let total = byDirection[direction]?.total ?? 0
        let maxTotal = Direction.allCases
            .map { byDirection[$0]?.total ?? 0 }
            .max() ?? 0
        guard maxTotal > 0 else { return 0 }
        return Double(total) / Double(maxTotal)
    }

    /// Percentage of all misses that landed in this direction.
    public func percent(for direction: Direction) -> Double {
        let total = byDirection[direction]?.total ?? 0
        guard totalMisses > 0 else { return 0 }
        return Double(total) / Double(totalMisses)
    }
}

// MARK: - Putt make-percentage

/// Inclusive distance bucket in feet, chosen to avoid over-segmenting
/// at long range where amateur sample sizes are thin.
public enum PuttBucket: String, CaseIterable, Sendable, Identifiable {
    case feet0to3 = "0–3"
    case feet4to6 = "4–6"
    case feet7to10 = "7–10"
    case feet11to15 = "11–15"
    case feet16to20 = "16–20"
    case feet21to30 = "21–30"
    case feet31plus = "31+"

    public var id: String {
        rawValue
    }

    /// Inclusive feet range. `feet31plus` collapses to "≥ 31".
    public var range: ClosedRange<Int> {
        switch self {
        case .feet0to3: return 0...3
        case .feet4to6: return 4...6
        case .feet7to10: return 7...10
        case .feet11to15: return 11...15
        case .feet16to20: return 16...20
        case .feet21to30: return 21...30
        case .feet31plus: return 31...Int.max
        }
    }

    public static func bucket(forFeet feet: Int) -> Self {
        guard feet > 0 else { return .feet0to3 }
        for bucket in allCases where bucket.range.contains(feet) {
            return bucket
        }
        return .feet31plus
    }
}

/// Per-bucket make / attempted tally.
public struct PuttMakeStat: Sendable, Equatable {
    public let made: Int
    public let attempted: Int
    public init(made: Int = 0, attempted: Int = 0) {
        self.made = made
        self.attempted = attempted
    }

    public var rate: Double? {
        attempted > 0 ? Double(made) / Double(attempted) : nil
    }
}

// MARK: - Hole heat matrix

/// A single round's row in the 20-round heat grid.
public struct HoleHeatRow: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    /// 18 cells. `nil` when the hole wasn't played (front-9 or back-9
    /// rounds; missing data).
    public let cells: [Cell?]

    public struct Cell: Sendable, Equatable, Hashable {
        public let strokes: Int
        public let par: Int
        public var vsPar: Int {
            strokes - par
        }

        public init(strokes: Int, par: Int) {
            self.strokes = strokes
            self.par = par
        }
    }

    public init(id: UUID, date: Date, cells: [Cell?]) {
        self.id = id
        self.date = date
        self.cells = cells
    }
}

/// Four-bucket score-outcome distribution for the scoring carousel.
/// Mirrors the heat-grid color mapping (birdie+, par, bogey, double+).
public enum HoleOutcome: String, CaseIterable, Sendable, Identifiable {
    case birdiePlus
    case par
    case bogey
    case doublePlus

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .birdiePlus: return "BIRDIE OR BETTER"
        case .par: return "PAR"
        case .bogey: return "BOGEY"
        case .doublePlus: return "DOUBLE OR WORSE"
        }
    }

    public static func outcome(forVsPar diff: Int) -> HoleOutcome {
        if diff <= -1 { return .birdiePlus }
        if diff == 0 { return .par }
        if diff == 1 { return .bogey }
        return .doublePlus
    }
}

// MARK: - Carousel aggregates payload

public struct TrendCarouselAggregates: Sendable, Equatable {
    public let fairwayRose: WindRoseData
    public let greenRose: WindRoseData
    public let makePctByDistance: [PuttBucket: PuttMakeStat]
    public let outcomes: [HoleOutcome: Int]
    public let outcomesTotal: Int
    public let holeHeatLast20: [HoleHeatRow]

    public init(
        fairwayRose: WindRoseData,
        greenRose: WindRoseData,
        makePctByDistance: [PuttBucket: PuttMakeStat],
        outcomes: [HoleOutcome: Int],
        outcomesTotal: Int,
        holeHeatLast20: [HoleHeatRow]
    ) {
        self.fairwayRose = fairwayRose
        self.greenRose = greenRose
        self.makePctByDistance = makePctByDistance
        self.outcomes = outcomes
        self.outcomesTotal = outcomesTotal
        self.holeHeatLast20 = holeHeatLast20
    }

    public static let empty = TrendCarouselAggregates(
        fairwayRose: .empty,
        greenRose: .empty,
        makePctByDistance: [:],
        outcomes: [:],
        outcomesTotal: 0,
        holeHeatLast20: []
    )

    /// `eligible` (post-filter) feeds the rose/putt/outcome stats;
    /// `allRounds` feeds the last-20 heat grid, which deliberately
    /// ignores the filter so it stays stable as the user toggles it.
    public static func build(
        eligible: [CompletedRound],
        allRounds: [CompletedRound]
    ) -> TrendCarouselAggregates {
        TrendCarouselAggregates(
            fairwayRose: buildFairwayRose(from: eligible),
            greenRose: buildGreenRose(from: eligible),
            makePctByDistance: buildMakePct(from: eligible),
            outcomes: buildOutcomes(from: eligible),
            outcomesTotal: eligible.flatMap(\.holeStats).filter { $0.strokes > 0 }.count,
            holeHeatLast20: buildHeatGrid(from: allRounds)
        )
    }
}

// MARK: - Builders

private extension TrendCarouselAggregates {
    static func buildFairwayRose(from rounds: [CompletedRound]) -> WindRoseData {
        var byDirection: [WindRoseData.Direction: WindRoseData.DirectionStack] = [:]
        var hits = 0
        var opportunities = 0
        var totalMisses = 0
        for hole in rounds.flatMap(\.holeStats) where hole.fairwayOpportunity {
            opportunities += 1
            if hole.fairwayInRegulation {
                hits += 1
                continue
            }
            // Fairway-leg roses only meaningfully track L/R.
            let directionFromLie = lieDirection(hole.teeShotLie) ?? .left
            var stack = byDirection[directionFromLie] ?? .init()
            switch hole.teeShotLie {
            case .bunkerLeft, .bunkerRight, .bunkerShort, .bunkerLong:
                stack.bunker += 1
            case .recoveryLeft, .recoveryRight, .recoveryShort, .recoveryLong:
                stack.clean += 1
            case .roughLeft, .roughRight, .fairway, .green, .none:
                stack.clean += 1
            }
            // Only L/R OB makes sense off the tee; long/short belongs to the approach.
            stack.ob += hole.outOfBoundsLeft + hole.outOfBoundsRight + hole.outOfBoundsLong + hole.outOfBoundsShort > 0
                ? hole.outOfBoundsCount
                : 0
            stack.water += hole.hazardCount
            byDirection[directionFromLie] = stack
            totalMisses += 1
        }
        let hitRate: Double? = opportunities > 0
            ? Double(hits) / Double(opportunities)
            : nil
        return WindRoseData(
            hitRate: hitRate,
            opportunities: opportunities,
            totalMisses: totalMisses,
            byDirection: byDirection
        )
    }

    static func buildGreenRose(from rounds: [CompletedRound]) -> WindRoseData {
        var byDirection: [WindRoseData.Direction: WindRoseData.DirectionStack] = [:]
        var hits = 0
        var opportunities = 0
        var totalMisses = 0
        for hole in rounds.flatMap(\.holeStats) where hole.strokes > 0 {
            opportunities += 1
            if hole.greenInRegulation {
                hits += 1
                continue
            }
            // Relevant lie is the approach lie on par 4/5, the tee lie on par 3.
            let missLie: Lie? = hole.par == 3 ? hole.teeShotLie : hole.approachLie
            let direction = lieDirection(missLie) ?? .short
            var stack = byDirection[direction] ?? .init()
            switch missLie {
            case .bunkerLeft, .bunkerRight, .bunkerShort, .bunkerLong:
                stack.bunker += 1
            case .recoveryLeft, .recoveryRight, .recoveryShort, .recoveryLong:
                stack.clean += 1
            case .roughLeft, .roughRight, .fairway, .green, .none:
                stack.clean += 1
            }
            let dirOB = directionalOB(hole, for: direction)
            let dirWater = directionalHazard(hole, for: direction)
            stack.ob += dirOB
            stack.water += dirWater
            byDirection[direction] = stack
            totalMisses += 1
        }
        let hitRate: Double? = opportunities > 0
            ? Double(hits) / Double(opportunities)
            : nil
        return WindRoseData(
            hitRate: hitRate,
            opportunities: opportunities,
            totalMisses: totalMisses,
            byDirection: byDirection
        )
    }

    static func buildMakePct(from rounds: [CompletedRound]) -> [PuttBucket: PuttMakeStat] {
        var tally: [PuttBucket: (made: Int, attempted: Int)] = [:]
        for hole in rounds.flatMap(\.holeStats) {
            guard let distances = hole.puttDistances, !distances.isEmpty else { continue }
            for (index, feet) in distances.enumerated() {
                let bucket = PuttBucket.bucket(forFeet: feet)
                var entry = tally[bucket] ?? (made: 0, attempted: 0)
                entry.attempted += 1
                // Heuristic: the last logged putt is the make.
                if index == distances.count - 1 {
                    entry.made += 1
                }
                tally[bucket] = entry
            }
        }
        return tally.mapValues { PuttMakeStat(made: $0.made, attempted: $0.attempted) }
    }

    static func buildOutcomes(from rounds: [CompletedRound]) -> [HoleOutcome: Int] {
        var counts: [HoleOutcome: Int] = [:]
        for hole in rounds.flatMap(\.holeStats) where hole.strokes > 0 {
            let outcome = HoleOutcome.outcome(forVsPar: hole.strokes - hole.par)
            counts[outcome, default: 0] += 1
        }
        return counts
    }

    static func buildHeatGrid(from rounds: [CompletedRound]) -> [HoleHeatRow] {
        let newestFirst = rounds.sorted { $0.datePlayed > $1.datePlayed }
        let last20 = Array(newestFirst.prefix(20))
        return last20.map { round in
            var cells: [HoleHeatRow.Cell?] = Array(repeating: nil, count: 18)
            for (index, hole) in round.holeStats.prefix(18).enumerated() where hole.strokes > 0 {
                cells[index] = HoleHeatRow.Cell(strokes: hole.strokes, par: hole.par)
            }
            return HoleHeatRow(id: round.id, date: round.datePlayed, cells: cells)
        }
    }
}

// MARK: - Lie → direction

/// Maps a `Lie` to the rose's miss direction; `nil` lets the caller
/// fall back to a default.
private func lieDirection(_ lie: Lie?) -> WindRoseData.Direction? {
    switch lie {
    case .roughLeft, .bunkerLeft, .recoveryLeft:
        return .left
    case .roughRight, .bunkerRight, .recoveryRight:
        return .right
    case .bunkerLong, .recoveryLong:
        return .long
    case .bunkerShort, .recoveryShort:
        return .short
    case .fairway, .green, .none:
        return nil
    }
}

/// Pulls directional OB counts off `HoleStat`, falling back to the
/// aggregate `outOfBoundsCount` for legacy rounds without per-direction data.
private func directionalOB(_ hole: HoleStat, for direction: WindRoseData.Direction) -> Int {
    let perDirectionSum = hole.outOfBoundsLeft + hole.outOfBoundsRight
        + hole.outOfBoundsLong + hole.outOfBoundsShort
    if perDirectionSum > 0 {
        switch direction {
        case .left: return hole.outOfBoundsLeft
        case .right: return hole.outOfBoundsRight
        case .long: return hole.outOfBoundsLong
        case .short: return hole.outOfBoundsShort
        }
    }
    return hole.outOfBoundsCount
}

private func directionalHazard(_ hole: HoleStat, for direction: WindRoseData.Direction) -> Int {
    let perDirectionSum = hole.hazardLeft + hole.hazardRight
        + hole.hazardLong + hole.hazardShort
    if perDirectionSum > 0 {
        switch direction {
        case .left: return hole.hazardLeft
        case .right: return hole.hazardRight
        case .long: return hole.hazardLong
        case .short: return hole.hazardShort
        }
    }
    return hole.hazardCount
}
