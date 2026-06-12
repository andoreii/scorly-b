import Foundation
import ScorlyDomain

/// Sample window — Trends shows either the last 10 or last 20 completed
/// rounds, each with a prior-window counterpart for delta comparisons.
public enum TrendsWindow: Int, CaseIterable, Sendable {
    case ten = 10
    case twenty = 20

    public var label: String {
        "LAST \(rawValue)"
    }
}

/// One round's contribution to the timeline. Pre-baked so the view
/// layer never has to know about `CompletedRound` internals.
public struct TrendsTimelinePoint: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let date: Date
    public let scoreVsPar: Int
    /// Raw total strokes; the score line graph plots this instead of vs-par.
    public let totalScore: Int
    public let threePutts: Int
    public let penalties: Int

    public init(
        id: UUID,
        date: Date,
        scoreVsPar: Int,
        totalScore: Int,
        threePutts: Int,
        penalties: Int
    ) {
        self.id = id
        self.date = date
        self.scoreVsPar = scoreVsPar
        self.totalScore = totalScore
        self.threePutts = threePutts
        self.penalties = penalties
    }
}

/// Score-distribution buckets, in scorecard order (lowest to highest
/// relative to par). Names match the in-app pip notation vocabulary.
public enum ScoreBucket: String, CaseIterable, Sendable {
    case eagleOrBetter = "EAGLE+"
    case birdie = "BIRDIE"
    case par = "PAR"
    case bogey = "BOGEY"
    case doublePlus = "DBL+"

    /// Used to bucket a hole's `score − par`.
    public static func bucket(forVsPar diff: Int) -> ScoreBucket {
        switch diff {
        case ...(-2): .eagleOrBetter
        case -1: .birdie
        case 0: .par
        case 1: .bogey
        default: .doublePlus
        }
    }
}

/// Per-metric sparkline series. The values are normalised by the
/// view, not here — chart primitives own their own scaling.
public struct MetricSpark: Sendable, Equatable {
    public let label: String
    public let value: String
    public let sub: String
    public let series: [Double]
    /// True when "lower is better" for the metric (putts, 3-putt %).
    /// Drives whether the most recent point's badge reads + or − vs
    /// the window average.
    public let lowerIsBetter: Bool

    public init(
        label: String,
        value: String,
        sub: String,
        series: [Double],
        lowerIsBetter: Bool
    ) {
        self.label = label
        self.value = value
        self.sub = sub
        self.series = series
        self.lowerIsBetter = lowerIsBetter
    }
}

/// SG category breakdown, normalised so the divergent bar can scale
/// every category to the same axis.
public struct SGBreakdownRow: Sendable, Equatable, Identifiable {
    public let category: SGCategory
    public let average: Double
    public init(category: SGCategory, average: Double) {
        self.category = category
        self.average = average
    }

    public var id: SGCategory {
        category
    }

    public var label: String {
        category.rawValue.uppercased()
    }
}

/// Pre-baked Trends payload — all math lives here, the view just renders.
public struct TrendsModel: Sendable, Equatable {
    public let window: TrendsWindow

    // Identity
    public let sampleCount: Int
    public let dateSpan: ClosedRange<Date>?

    // Headline
    public let avgVsPar: Double?
    public let avgVsParPrev: Double?
    public let bestVsPar: Int?
    public let worstVsPar: Int?
    public let avgScore: Double?

    // Timeline + streak
    public let timeline: [TrendsTimelinePoint]
    public let streak: [Int]

    // Distribution
    /// Denominator for the distribution chart — summary-only rounds
    /// (no hole stats) don't contribute here even though they count
    /// toward score/handicap math.
    public let distributionHoles: Int
    public let distribution: [ScoreBucket: Int]

    /// nil when no round in the sample has SG totals recorded.
    public let sg: [SGBreakdownRow]?

    // Accuracy grid
    public let firRate: Double?
    public let girRate: Double?
    public let puttsPerRound: Double?
    public let threePuttRate: Double?
    /// Rate of one-putt holes, used alongside `threePuttRate` in the
    /// touch carousel's mini-stats.
    public let onePuttRate: Double?
    public let firSeries: [Double]
    public let girSeries: [Double]
    public let puttsSeries: [Double]
    public let threePuttSeries: [Double]
    /// Parallels `firSeries` / `girSeries`; rounds without hole stats
    /// are skipped, so this may be shorter than `timeline`.
    public let accuracyDates: [Date]

    // Penalty heatmap
    public let penalties: [Int]
    public let penaltyMax: Int

    /// Eight-axis skills radar inputs, computed from scorecard measures
    /// so imported rounds stay comparable even without full SG.
    public let radarAxes: [RadarAxis]

    public init(
        window: TrendsWindow,
        sampleCount: Int,
        dateSpan: ClosedRange<Date>?,
        avgVsPar: Double?,
        avgVsParPrev: Double?,
        bestVsPar: Int?,
        worstVsPar: Int?,
        avgScore: Double?,
        timeline: [TrendsTimelinePoint],
        streak: [Int],
        distributionHoles: Int,
        distribution: [ScoreBucket: Int],
        sg: [SGBreakdownRow]?,
        firRate: Double?,
        girRate: Double?,
        puttsPerRound: Double?,
        threePuttRate: Double?,
        onePuttRate: Double? = nil,
        firSeries: [Double],
        girSeries: [Double],
        puttsSeries: [Double],
        threePuttSeries: [Double],
        accuracyDates: [Date] = [],
        penalties: [Int],
        penaltyMax: Int,
        radarAxes: [RadarAxis] = []
    ) {
        self.window = window
        self.sampleCount = sampleCount
        self.dateSpan = dateSpan
        self.avgVsPar = avgVsPar
        self.avgVsParPrev = avgVsParPrev
        self.bestVsPar = bestVsPar
        self.worstVsPar = worstVsPar
        self.avgScore = avgScore
        self.timeline = timeline
        self.streak = streak
        self.distributionHoles = distributionHoles
        self.distribution = distribution
        self.sg = sg
        self.firRate = firRate
        self.girRate = girRate
        self.puttsPerRound = puttsPerRound
        self.threePuttRate = threePuttRate
        self.onePuttRate = onePuttRate
        self.firSeries = firSeries
        self.girSeries = girSeries
        self.puttsSeries = puttsSeries
        self.threePuttSeries = threePuttSeries
        self.accuracyDates = accuracyDates
        self.penalties = penalties
        self.penaltyMax = penaltyMax
        self.radarAxes = radarAxes
    }

    /// Empty model for the empty-state branch (no rounds yet).
    public static func empty(window: TrendsWindow) -> TrendsModel {
        TrendsModel(
            window: window,
            sampleCount: 0,
            dateSpan: nil,
            avgVsPar: nil,
            avgVsParPrev: nil,
            bestVsPar: nil,
            worstVsPar: nil,
            avgScore: nil,
            timeline: [],
            streak: [],
            distributionHoles: 0,
            distribution: [:],
            sg: nil,
            firRate: nil,
            girRate: nil,
            puttsPerRound: nil,
            threePuttRate: nil,
            firSeries: [],
            girSeries: [],
            puttsSeries: [],
            threePuttSeries: [],
            penalties: [],
            penaltyMax: 0,
            radarAxes: RadarAxisKey.allCases.map {
                RadarAxis(key: $0, windowValue: 0, seasonValue: 0)
            }
        )
    }

    // MARK: - Build

    /// `rounds` should be newest-first; re-ordered chronologically for the timeline.
    public static func build(
        rounds: [CompletedRound],
        window: TrendsWindow
    ) -> TrendsModel {
        guard !rounds.isEmpty else { return .empty(window: window) }

        let newestFirst = rounds.sorted { $0.datePlayed > $1.datePlayed }
        let n = window.rawValue
        let sample = Array(newestFirst.prefix(n))
        let prior = Array(newestFirst.dropFirst(n).prefix(n))
        // Chart consumes chronological (oldest → newest, left → right).
        let chrono = sample.sorted { $0.datePlayed < $1.datePlayed }

        // Headline figures
        let vsPar = sample.map(\.scoreVsPar)
        let avgVsPar = vsPar.isEmpty ? nil : Double(vsPar.reduce(0, +)) / Double(vsPar.count)
        let priorVsPar = prior.map(\.scoreVsPar)
        let avgVsParPrev = priorVsPar.isEmpty
            ? nil
            : Double(priorVsPar.reduce(0, +)) / Double(priorVsPar.count)
        let bestVsPar = vsPar.min()
        let worstVsPar = vsPar.max()
        let avgScore = sample.isEmpty
            ? nil
            : Double(sample.reduce(0) { $0 + $1.totalScore }) / Double(sample.count)

        let dateSpan: ClosedRange<Date>? = {
            guard
                let first = chrono.first?.datePlayed,
                let last = chrono.last?.datePlayed
            else { return nil }
            return first <= last ? first...last : last...first
        }()

        // Timeline + streak
        let timeline: [TrendsTimelinePoint] = chrono.map { round in
            TrendsTimelinePoint(
                id: round.id,
                date: round.datePlayed,
                scoreVsPar: round.scoreVsPar,
                totalScore: round.totalScore,
                threePutts: round.threePuttCount,
                penalties: round.holeStats.reduce(0) { $0 + $1.effectivePenaltyStrokes }
            )
        }
        let streak = chrono.map(\.scoreVsPar)

        // Distribution: bucket every hole in the sample (skipping
        // rounds with no recorded hole stats).
        var bucketCounts: [ScoreBucket: Int] = [:]
        var distributionHoles = 0
        for round in sample {
            for hole in round.holeStats {
                guard hole.strokes > 0 else { continue }
                distributionHoles += 1
                let bucket = ScoreBucket.bucket(forVsPar: hole.strokes - hole.par)
                bucketCounts[bucket, default: 0] += 1
            }
        }

        // SG averages — only the subset that has totals recorded.
        let sgSamples = sample.compactMap(\.sgTotals)
        let sg: [SGBreakdownRow]? = {
            guard !sgSamples.isEmpty else { return nil }
            let count = Double(sgSamples.count)
            return SGCategory.allCases.map { cat in
                let total: Double = sgSamples.reduce(0) { acc, totals in
                    acc + (NSDecimalNumber(decimal: totals.value(for: cat)).doubleValue)
                }
                return SGBreakdownRow(category: cat, average: total / count)
            }
        }()

        // Accuracy series (oldest → newest, percentages 0…1).
        var firSeries: [Double] = []
        var girSeries: [Double] = []
        var puttsSeries: [Double] = []
        var threePuttSeries: [Double] = []
        var accuracyDates: [Date] = []
        var firNumerator = 0
        var firDenominator = 0
        var girNumerator = 0
        var girDenominator = 0
        var totalPutts = 0
        var totalHoles = 0
        var threePuttCount = 0
        var onePuttCount = 0

        for round in chrono {
            let holes = round.holeStats
            guard !holes.isEmpty else {
                // Skip rather than emit a zero, so the sparkline doesn't dip artificially.
                continue
            }
            let girHoles = holes.count
            let firOpps = round.firOpportunities
            firSeries.append(firOpps > 0 ? Double(round.firCount) / Double(firOpps) : 0)
            girSeries.append(Double(round.girCount) / Double(girHoles))
            puttsSeries.append(Double(round.totalPutts) / Double(girHoles) * 18.0)
            threePuttSeries.append(Double(round.threePuttCount) / Double(girHoles))
            accuracyDates.append(round.datePlayed)

            firNumerator += round.firCount
            firDenominator += firOpps
            girNumerator += round.girCount
            girDenominator += girHoles
            totalPutts += round.totalPutts
            totalHoles += girHoles
            threePuttCount += round.threePuttCount
            onePuttCount += holes.filter { $0.putts == 1 }.count
        }

        let firRate: Double? = firDenominator > 0
            ? Double(firNumerator) / Double(firDenominator)
            : nil
        let girRate: Double? = girDenominator > 0
            ? Double(girNumerator) / Double(girDenominator)
            : nil
        let puttsPerRound: Double? = totalHoles > 0
            ? (Double(totalPutts) / Double(totalHoles)) * 18.0
            : nil
        let threePuttRate: Double? = totalHoles > 0
            ? Double(threePuttCount) / Double(totalHoles)
            : nil
        let onePuttRate: Double? = totalHoles > 0
            ? Double(onePuttCount) / Double(totalHoles)
            : nil

        // Penalty heatmap (chronological, one cell per round).
        let penalties = timeline.map(\.penalties)
        let penaltyMax = penalties.max() ?? 0

        // Radar: this window vs season avg (`rounds` is the eligible set).
        let radarAxes = RadarAxis.makeAll(window: sample, season: rounds)

        return TrendsModel(
            window: window,
            sampleCount: sample.count,
            dateSpan: dateSpan,
            avgVsPar: avgVsPar,
            avgVsParPrev: avgVsParPrev,
            bestVsPar: bestVsPar,
            worstVsPar: worstVsPar,
            avgScore: avgScore,
            timeline: timeline,
            streak: streak,
            distributionHoles: distributionHoles,
            distribution: bucketCounts,
            sg: sg,
            firRate: firRate,
            girRate: girRate,
            puttsPerRound: puttsPerRound,
            threePuttRate: threePuttRate,
            onePuttRate: onePuttRate,
            firSeries: firSeries,
            girSeries: girSeries,
            puttsSeries: puttsSeries,
            threePuttSeries: threePuttSeries,
            accuracyDates: accuracyDates,
            penalties: penalties,
            penaltyMax: penaltyMax,
            radarAxes: radarAxes
        )
    }
}
