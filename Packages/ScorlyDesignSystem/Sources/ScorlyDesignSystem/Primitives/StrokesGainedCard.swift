import SwiftUI

/// Per-category Strokes Gained values shaped for the design system.
/// Mirrors `ScorlyDomain.SGTotals`. Defined here so this primitive
/// layer can stay free of Domain imports (per ArchitectureTests).
/// Callers map at the feature boundary.
public struct SGCardValues: Sendable, Equatable {
    public let ott: Decimal
    public let app: Decimal
    public let arg: Decimal
    public let putt: Decimal
    public let total: Decimal

    public init(ott: Decimal, app: Decimal, arg: Decimal, putt: Decimal, total: Decimal) {
        self.ott = ott
        self.app = app
        self.arg = arg
        self.putt = putt
        self.total = total
    }
}

/// Strokes Gained "01 Full" panel — the literal port of the Claude
/// design at `Scorly B Strokes Gained.html`. Header total + vs-season
/// delta, 4-row category diverging bars with season-avg ghosts,
/// 18-hole timeline with cumulative trace, and a best/worst/net
/// summary strip.
///
/// Accepts already-computed values (no `CompletedRound`) so the same
/// card can be driven from a saved round on Round Detail or from a
/// live `RoundPlayState` once Sign & File is unified with this layout.
///
/// `total == nil` triggers the placeholder branch: same frame +
/// header, no bars/timeline/summary, inline mono message explaining
/// SG requires distances.
public struct StrokesGainedCard: View {
    private let meta: String
    private let title: String
    private let total: SGCardValues?
    private let holes: [SGCardValues]?
    private let seasonAverages: SGCardValues?
    private let referenceLabel: String
    private let timelineTitle: String
    private let timelineUnitSingular: String
    private let timelineUnitPlural: String
    private let timelineXAxisTitle: String
    private let summaryStyle: SGSummaryStyle
    private let breakdownDensity: SGBreakdownDensity

    /// - Parameters:
    ///   - timelineTitle: Header on the bottom timeline panel
    ///     (default "HOLE-BY-HOLE SG · CUMULATIVE"). Multi-round
    ///     callers can pass "ROUND-BY-ROUND SG · CUMULATIVE".
    ///   - timelineUnitSingular / Plural: nouns substituted into the
    ///     "\(count) HOLES" caption — multi-round callers pass
    ///     "ROUND" / "ROUNDS".
    ///   - timelineXAxisTitle: X-axis label drawn inside the
    ///     timeline chart (default "HOLE"). Multi-round callers pass
    ///     "ROUND".
    public init(
        meta: String,
        title: String = "Strokes gained",
        total: SGCardValues?,
        holes: [SGCardValues]? = nil,
        seasonAverages: SGCardValues? = nil,
        referenceLabel: String = "VS SCRATCH",
        timelineTitle: String = "HOLE-BY-HOLE SG · CUMULATIVE",
        timelineUnitSingular: String = "HOLE",
        timelineUnitPlural: String = "HOLES",
        timelineXAxisTitle: String = "HOLE",
        summaryStyle: SGSummaryStyle = .full,
        breakdownDensity: SGBreakdownDensity = .standard
    ) {
        self.meta = meta
        self.title = title
        self.total = total
        self.holes = holes
        self.seasonAverages = seasonAverages
        self.referenceLabel = referenceLabel
        self.timelineTitle = timelineTitle
        self.timelineUnitSingular = timelineUnitSingular
        self.timelineUnitPlural = timelineUnitPlural
        self.timelineXAxisTitle = timelineXAxisTitle
        self.summaryStyle = summaryStyle
        self.breakdownDensity = breakdownDensity
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.bg
            CornerMarks()
            VStack(alignment: .leading, spacing: 0) {
                header
                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(height: 1)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                referenceRow
                if let total {
                    if summaryStyle == .categoryExtremes {
                        Spacer(minLength: BrutalistSpacing.s)
                    }
                    SGDivergingBars(
                        values: total,
                        seasonAverages: seasonAverages,
                        density: breakdownDensity
                    )
                    .padding(.top, summaryStyle == .full ? 14 : 0)
                    legend
                    timelineCard
                    if summaryStyle == .categoryExtremes {
                        Spacer(minLength: BrutalistSpacing.s)
                    }
                    summaryStrip(total: total)
                } else {
                    placeholder
                }
            }
            .padding(18)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meta)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(title)
                    .font(BrutalistType.sans(.bold, size: 24))
                    .kerning(-0.6)
                    .foregroundStyle(BrutalistColor.fg)
            }
            Spacer(minLength: BrutalistSpacing.m)
            if let total {
                totalStamp(total)
            }
        }
    }

    private func totalStamp(_ total: SGCardValues) -> some View {
        let totalDouble = sgDecimalToDouble(total.total)
        return VStack(alignment: .trailing, spacing: 4) {
            Text("TOTAL SG")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.dim)
            Text(sgFormat(total.total))
                .font(BrutalistType.sans(.bold, size: 38))
                .kerning(-1.4)
                .monospacedDigit()
                .foregroundStyle(totalDouble >= 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg)
                .lineLimit(1)
            if let seasonAverages {
                let diff = totalDouble - sgDecimalToDouble(seasonAverages.total)
                Text(sgFormatDiffSeason(diff))
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
            }
        }
    }

    private var referenceRow: some View {
        HStack {
            Text("\(referenceLabel) · 4 CATEGORIES")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            Spacer()
            Text("0.00 = \(referenceLabel.replacingOccurrences(of: "VS ", with: ""))")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    // MARK: - Sections

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(swatch: AnyView(
                Rectangle()
                    .fill(BrutalistColor.sgPosFill)
                    .frame(width: 14, height: 8)
                    .overlay(Rectangle().stroke(BrutalistColor.sgPos, lineWidth: 1))
            ), label: "GAINED")
            legendItem(swatch: AnyView(
                Rectangle()
                    .fill(BrutalistColor.sgNegFill)
                    .frame(width: 14, height: 8)
                    .overlay(Rectangle().stroke(BrutalistColor.sgNeg, lineWidth: 1))
            ), label: "LOST")
            if seasonAverages != nil {
                legendItem(swatch: AnyView(
                    Circle()
                        .fill(BrutalistColor.bg)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(BrutalistColor.muted, lineWidth: 1))
                ), label: "SEASON AVG")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, breakdownDensity.legendTopPadding)
    }

    private func legendItem(swatch: AnyView, label: String) -> some View {
        HStack(spacing: 6) {
            swatch
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private var timelineCard: some View {
        Group {
            if let holes, !holes.isEmpty {
                ZStack(alignment: .topLeading) {
                    BrutalistColor.panel
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(timelineTitle)
                                .font(BrutalistType.monoMicro)
                                .kerning(1.0)
                                .foregroundStyle(BrutalistColor.muted)
                            Spacer()
                            Text("\(holes.count) \(holes.count == 1 ? timelineUnitSingular : timelineUnitPlural)")
                                .font(BrutalistType.monoMicro)
                                .kerning(0.8)
                                .foregroundStyle(BrutalistColor.muted)
                        }
                        SGHoleTimeline(holes: holes, xAxisTitle: timelineXAxisTitle)
                            .frame(height: 200)
                    }
                    .padding(12)
                }
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                .padding(.top, 18)
            }
        }
    }

    private func summaryStrip(total: SGCardValues) -> some View {
        HStack(spacing: 0) {
            ForEach(
                Array(SGSummaryItem.items(for: total, style: summaryStyle, referenceLabel: referenceLabel)
                    .enumerated()),
                id: \.offset
            ) { index, item in
                SGSummaryCell(
                    label: item.label,
                    title: item.title,
                    value: item.value,
                    short: item.short,
                    leadingBorder: index > 0
                )
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        .padding(.top, summaryStyle == .full ? 14 : BrutalistSpacing.s)
    }

    private var placeholder: some View {
        Text("SG REQUIRES TEE / APPROACH / PUTT DISTANCES — NOT RECORDED FOR THIS ROUND")
            .font(BrutalistType.monoMicro)
            .kerning(0.8)
            .foregroundStyle(BrutalistColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
    }
}

// MARK: - Categories

public enum SGSummaryStyle: Sendable {
    case full
    case categoryExtremes
}

public struct SGBreakdownDensity: Sendable {
    let rowHeight: CGFloat
    let rowSpacing: CGFloat
    let axisHeaderBottomPadding: CGFloat
    let legendTopPadding: CGFloat
    let valueColumnWidth: CGFloat
    let trackHorizontalPadding: CGFloat
    let labelTrailingPadding: CGFloat
    let trackHeight: CGFloat
    let usesStackedRows: Bool
    let showsCategoryCodes: Bool
    let repeatsAxisTicksPerRow: Bool
    let showsHeaderDivider: Bool
    let finalRowBottomPadding: CGFloat

    public static let standard = Self(
        rowHeight: 38,
        rowSpacing: 0,
        axisHeaderBottomPadding: 6,
        legendTopPadding: 10,
        valueColumnWidth: 84,
        trackHorizontalPadding: BrutalistSpacing.xxs,
        labelTrailingPadding: BrutalistSpacing.s,
        trackHeight: 24,
        usesStackedRows: false,
        showsCategoryCodes: true,
        repeatsAxisTicksPerRow: false,
        showsHeaderDivider: true,
        finalRowBottomPadding: 0
    )

    public static let spacious = Self(
        rowHeight: 68,
        rowSpacing: BrutalistSpacing.xxs,
        axisHeaderBottomPadding: BrutalistSpacing.m,
        legendTopPadding: BrutalistSpacing.l,
        valueColumnWidth: 64,
        trackHorizontalPadding: 0,
        labelTrailingPadding: 0,
        trackHeight: 22,
        usesStackedRows: true,
        showsCategoryCodes: false,
        repeatsAxisTicksPerRow: true,
        showsHeaderDivider: false,
        finalRowBottomPadding: BrutalistSpacing.m
    )
}

struct SGCategorySpec {
    let short: String
    let label: String
    let totalsKeyPath: KeyPath<SGCardValues, Decimal> & Sendable
}

let sgCategories: [SGCategorySpec] = [
    SGCategorySpec(short: "SG:OTT", label: "OFF THE TEE", totalsKeyPath: \SGCardValues.ott),
    SGCategorySpec(short: "SG:APP", label: "APPROACH", totalsKeyPath: \SGCardValues.app),
    SGCategorySpec(short: "SG:ARG", label: "AROUND THE GREEN", totalsKeyPath: \SGCardValues.arg),
    SGCategorySpec(short: "SG:PUTT", label: "PUTTING", totalsKeyPath: \SGCardValues.putt),
]

// MARK: - Summary cell

struct SGSummaryItem {
    let label: String
    let title: String
    let value: Double
    let short: String?

    static func items(for total: SGCardValues, style: SGSummaryStyle, referenceLabel: String) -> [Self] {
        let ranked = sgCategories.map { ($0, sgDecimalToDouble(total[keyPath: $0.totalsKeyPath])) }
        let sorted = ranked.sorted { $0.1 > $1.1 }
        let best = sorted.first ?? ranked[0]
        let worst = sorted.last ?? ranked[0]
        var items = [
            Self(label: "BEST CATEGORY", title: best.0.label, value: best.1, short: best.0.short),
            Self(label: "WORST CATEGORY", title: worst.0.label, value: worst.1, short: worst.0.short),
        ]
        if style == .full {
            items.append(
                Self(
                    label: "NET \(referenceLabel)",
                    title: "ALL CATEGORIES",
                    value: sgDecimalToDouble(total.total),
                    short: nil
                )
            )
        }
        return items
    }
}

struct SGSummaryCell: View {
    let label: String
    let title: String
    let value: Double
    let short: String?
    var leadingBorder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(title)
                .font(BrutalistType.sans(.semibold, size: 13))
                .kerning(-0.2)
                .foregroundStyle(BrutalistColor.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(sgFormat(Decimal(value)))
                    .font(BrutalistType.mono(.semibold, size: 22))
                    .monospacedDigit()
                    .foregroundStyle(value >= 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg)
                if let short {
                    Text(short)
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            if leadingBorder {
                Rectangle().fill(BrutalistColor.rule).frame(width: 1)
            }
        }
    }
}

// MARK: - Helpers

func sgFormat(_ value: Decimal) -> String {
    let double = sgDecimalToDouble(value)
    if double == 0 { return "0.00" }
    let text = String(format: "%.2f", abs(double))
    return double > 0 ? "+\(text)" : "-\(text)"
}

func sgFormatDiffSeason(_ diff: Double) -> String {
    let text = String(format: "%.2f", abs(diff))
    let signed = diff >= 0 ? "+\(text)" : "-\(text)"
    return "\(signed) VS SEASON"
}

func sgDecimalToDouble(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
}

func sgClamp<Value: Comparable>(_ value: Value, _ lower: Value, _ upper: Value) -> Value {
    min(max(value, lower), upper)
}
