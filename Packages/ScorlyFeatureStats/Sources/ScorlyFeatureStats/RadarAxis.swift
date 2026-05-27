import Foundation
import ScorlyDomain

/// One axis of the Skills Radar. Eight of these are computed from the
/// trend sample and rendered clockwise from the top.
public enum RadarAxisKey: String, CaseIterable, Sendable {
    case putting
    case teeAccuracy
    case drivingDistance
    case approach
    case shortGame
    case scrambling
    case troubleAvoidance
    case bogeyAvoidance

    /// Long form, used as the axis label outside the polygon.
    public var label: String {
        switch self {
        case .putting: "PUTTING"
        case .teeAccuracy: "TEE ACCURACY"
        case .drivingDistance: "DRIVING DIST."
        case .approach: "APPROACH"
        case .shortGame: "SHORT GAME"
        case .scrambling: "SCRAMBLING"
        case .troubleAvoidance: "TROUBLE AVOID."
        case .bogeyAvoidance: "BOGEY AVOID."
        }
    }

    /// Short form for the Areas list table header.
    public var shortLabel: String {
        switch self {
        case .putting: "PUTT"
        case .teeAccuracy: "TEE"
        case .drivingDistance: "DIST"
        case .approach: "APPR"
        case .shortGame: "SHORT"
        case .scrambling: "SCRM"
        case .troubleAvoidance: "TRBL"
        case .bogeyAvoidance: "BOGA"
        }
    }

    /// Medium-length form used by the radar polygon — needs to fit
    /// next to the spoke without overflowing the card. The full name
    /// still appears in the expanded Areas table and the summary strip.
    public var polygonLabel: String {
        switch self {
        case .putting: "PUTTING"
        case .teeAccuracy: "TEE ACC."
        case .drivingDistance: "DRIVING"
        case .approach: "APPROACH"
        case .shortGame: "SHORT"
        case .scrambling: "SCRAMBLE"
        case .troubleAvoidance: "TROUBLE"
        case .bogeyAvoidance: "BOGEY"
        }
    }
}

/// One axis carrying its 0-100 normalized skill score for the active
/// sample window and for the broader season sample.
public struct RadarAxis: Sendable, Equatable, Identifiable {
    public let key: RadarAxisKey
    /// Normalized score for the current sample window polygon.
    public let windowValue: Int
    /// Normalized score for the full eligible season.
    public let seasonValue: Int

    public init(key: RadarAxisKey, windowValue: Int, seasonValue: Int) {
        self.key = key
        self.windowValue = windowValue
        self.seasonValue = seasonValue
    }

    public var id: RadarAxisKey {
        key
    }

    public var label: String {
        key.label
    }

    public var shortLabel: String {
        key.shortLabel
    }

    public var polygonLabel: String {
        key.polygonLabel
    }

    /// Window minus season — drives the "biggest mover" and the Δ column.
    public var delta: Int {
        windowValue - seasonValue
    }

    public var trendDirection: RadarTrendDirection {
        if delta > 0 { return .up }
        if delta < 0 { return .down }
        return .unchanged
    }
}

public enum RadarTrendDirection: Sendable, Equatable {
    case up
    case down
    case unchanged

    public var arrow: String? {
        switch self {
        case .up: "↑"
        case .down: "↓"
        case .unchanged: nil
        }
    }
}

// MARK: - Build

public extension RadarAxis {
    /// Selects the primary skill strength shown in the summary strip.
    /// Trouble avoidance stays visible on the radar but is not framed
    /// as the player's leading skill.
    static func strongest(in axes: [RadarAxis]) -> RadarAxis? {
        axes
            .filter { $0.key != .troubleAvoidance }
            .max { $0.windowValue < $1.windowValue }
    }

    /// Build all eight axes from measurements recorded on the scorecard.
    /// SG is kept in its dedicated analysis block; it is not used here
    /// because historical/imported shots cannot fully reconstruct missed
    /// approach and recovery endpoints.
    static func makeAll(window: [CompletedRound], season: [CompletedRound]) -> [RadarAxis] {
        RadarAxisKey.allCases.map { key in
            RadarAxis(
                key: key,
                windowValue: percentile(key: key, rounds: window),
                seasonValue: percentile(key: key, rounds: season)
            )
        }
    }

    /// Public so tests can pin each anchor without spinning up a model.
    static func percentile(key: RadarAxisKey, rounds: [CompletedRound]) -> Int {
        switch key {
        case .putting:
            return rangeAxisPercentile(
                value: puttsPerEighteen(rounds: rounds),
                lower: 39,
                upper: 27
            )
        case .teeAccuracy:
            return rateAxisPercentile(
                rate: firRate(rounds: rounds),
                lower: 0.20,
                upper: 0.70
            )
        case .drivingDistance:
            return rangeAxisPercentile(
                value: avgDrivingDistance(rounds: rounds),
                lower: 190,
                upper: 290
            )
        case .approach:
            return rateAxisPercentile(
                rate: girRate(rounds: rounds),
                lower: 0.15,
                upper: 0.65
            )
        case .shortGame:
            return rateAxisPercentile(
                rate: shortGameTouchRate(rounds: rounds),
                lower: 0.0,
                upper: 0.55
            )
        case .scrambling:
            return rateAxisPercentile(
                rate: scramblingRate(rounds: rounds),
                lower: 0.0,
                upper: 0.65
            )
        case .troubleAvoidance:
            // Lower trouble per hole is better — invert the band.
            return rateAxisPercentile(
                rate: troublePerHole(rounds: rounds),
                lower: 0.35,
                upper: 0.0
            )
        case .bogeyAvoidance:
            // Fewer bogey+ holes is better — invert the band.
            return rateAxisPercentile(
                rate: bogeyPlusRate(rounds: rounds),
                lower: 0.70,
                upper: 0.25
            )
        }
    }

    // MARK: - Metric helpers

    private static func rateAxisPercentile(
        rate: Double?,
        lower: Double,
        upper: Double
    ) -> Int {
        guard let rate else { return clampPercentile(0) }
        return percentile(value: rate, lower: lower, upper: upper)
    }

    private static func rangeAxisPercentile(
        value: Double?,
        lower: Double,
        upper: Double
    ) -> Int {
        guard let value else { return clampPercentile(0) }
        return percentile(value: value, lower: lower, upper: upper)
    }

    private static func firRate(rounds: [CompletedRound]) -> Double? {
        let num = rounds.reduce(0) { $0 + $1.firCount }
        let den = rounds.reduce(0) { $0 + $1.firOpportunities }
        guard den > 0 else { return nil }
        return Double(num) / Double(den)
    }

    private static func puttsPerEighteen(rounds: [CompletedRound]) -> Double? {
        let holes = playedHoles(rounds: rounds)
        guard !holes.isEmpty else { return nil }
        let putts = holes.reduce(0) { $0 + $1.putts }
        return Double(putts) / Double(holes.count) * 18
    }

    private static func girRate(rounds: [CompletedRound]) -> Double? {
        let holes = playedHoles(rounds: rounds)
        guard !holes.isEmpty else { return nil }
        let greens = holes.filter(\.greenInRegulation).count
        return Double(greens) / Double(holes.count)
    }

    private static func avgDrivingDistance(rounds: [CompletedRound]) -> Double? {
        var sum = 0
        var count = 0
        for round in rounds {
            for hole in round.holeStats where hole.par >= 4 {
                if let dist = hole.teeShotDistance, dist > 0 {
                    sum += dist
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        return Double(sum) / Double(count)
    }

    private static func shortGameTouchRate(rounds: [CompletedRound]) -> Double? {
        let misses = playedHoles(rounds: rounds).filter { !$0.greenInRegulation }
        guard !misses.isEmpty else { return nil }
        let onePuttOrBetter = misses.filter { $0.putts <= 1 }.count
        return Double(onePuttOrBetter) / Double(misses.count)
    }

    private static func scramblingRate(rounds: [CompletedRound]) -> Double? {
        var opportunities = 0
        var saves = 0
        for round in rounds {
            for hole in round.holeStats where hole.strokes > 0 && !hole.greenInRegulation {
                opportunities += 1
                if hole.upAndDown { saves += 1 }
            }
        }
        guard opportunities > 0 else { return nil }
        return Double(saves) / Double(opportunities)
    }

    private static func troublePerHole(rounds: [CompletedRound]) -> Double? {
        var trouble = 0
        var holes = 0
        for round in rounds {
            for hole in round.holeStats where hole.strokes > 0 {
                trouble += hole.effectivePenaltyStrokes
                holes += 1
            }
        }
        guard holes > 0 else { return nil }
        return Double(trouble) / Double(holes)
    }

    private static func bogeyPlusRate(rounds: [CompletedRound]) -> Double? {
        var bogeyPlus = 0
        var holes = 0
        for round in rounds {
            for hole in round.holeStats where hole.strokes > 0 {
                if hole.strokes - hole.par >= 1 { bogeyPlus += 1 }
                holes += 1
            }
        }
        guard holes > 0 else { return nil }
        return Double(bogeyPlus) / Double(holes)
    }

    private static func playedHoles(rounds: [CompletedRound]) -> [HoleStat] {
        rounds.flatMap(\.holeStats).filter { $0.strokes > 0 }
    }

    // MARK: - Percentile core

    /// Linear map `value ∈ [lower, upper] → 0…100`, clamped. If
    /// `lower > upper` the map is inverted (lower-is-better metrics).
    /// Tests pin behaviour at the anchors via this entry point.
    static func percentile(value: Double, lower: Double, upper: Double) -> Int {
        let span = upper - lower
        guard span != 0 else { return clampPercentile(value >= lower ? 100 : 0) }
        let raw = ((value - lower) / span) * 100
        return clampPercentile(raw)
    }

    private static func clampPercentile(_ raw: Double) -> Int {
        let bounded = max(0.0, min(100.0, raw))
        return Int(bounded.rounded())
    }
}
