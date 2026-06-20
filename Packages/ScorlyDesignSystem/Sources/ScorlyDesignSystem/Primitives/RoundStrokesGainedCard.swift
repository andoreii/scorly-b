import SwiftUI

public struct RoundStrokesGainedCard: View {
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
        timelineXAxisTitle: String = "HOLE"
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
    }

    public var body: some View {
        ReviewDisclosureCard(
            meta: meta,
            title: title,
            metric: total.map { "\(sgFormat($0.total)) SG" } ?? "SG UNAVAILABLE"
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if let total {
                    heroTotal(total)
                    HBar(vMargin: 14)
                    splitSection(total)
                    HBar(vMargin: 14)
                    categoryHeader
                    SGTrendDivergingBars(
                        values: total,
                        seasonAverages: seasonAverages,
                        categories: orderedCategories(for: total)
                    )
                    .padding(.top, 10)
                    categoryExtremesStrip(total: total)
                    timelineCard
                } else {
                    placeholder
                }
            }
        }
    }

    // MARK: - Single-round sections

    private func heroTotal(_ total: SGCardValues) -> some View {
        let totalDouble = sgDecimalToDouble(total.total)
        return VStack(alignment: .leading, spacing: 4) {
            Text("STROKES GAINED · TOTAL")
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            HStack(alignment: .bottom, spacing: 12) {
                Text(sgFormat(total.total))
                    .font(BrutalistType.sans(.bold, size: 68))
                    .kerning(-2.8)
                    .monospacedDigit()
                    .foregroundStyle(totalDouble >= 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                VStack(alignment: .leading, spacing: 3) {
                    Text(referenceLabel)
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                    if let seasonAverages {
                        let diff = totalDouble - sgDecimalToDouble(seasonAverages.total)
                        Text("\(diff >= 0 ? "↗" : "↘") \(sgFormat(Decimal(diff))) VS SEASON")
                            .font(BrutalistType.mono(.semibold, size: 11))
                            .kerning(0.3)
                            .foregroundStyle(diff >= 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func splitSection(_ total: SGCardValues) -> some View {
        let split = sgSplit(total)
        let span = split.gained + split.lost
        let gainedFraction = span > 0 ? split.gained / span : 0.5
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WHERE THEY WENT")
                Spacer()
                Text("STROKES")
            }
            .font(BrutalistType.monoMicro)
            .kerning(1.0)
            .foregroundStyle(BrutalistColor.muted)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(BrutalistColor.sgPosFill)
                        .frame(width: proxy.size.width * gainedFraction)
                    Rectangle()
                        .fill(BrutalistColor.sgNegFill)
                }
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            }
            .frame(height: 22)
            HStack {
                Text("▲ GAINED \(String(format: "%.2f", split.gained))")
                    .foregroundStyle(BrutalistColor.sgPos)
                Spacer()
                Text("LOST \(String(format: "%.2f", split.lost)) ▼")
                    .foregroundStyle(BrutalistColor.sgNeg)
            }
            .font(BrutalistType.mono(.semibold, size: 10))
            .kerning(0.4)
            .monospacedDigit()
        }
    }

    private var categoryHeader: some View {
        HStack {
            Text("BY CATEGORY")
            Spacer()
            Text("WORST → BEST")
        }
        .font(BrutalistType.monoMicro)
        .kerning(1.0)
        .foregroundStyle(BrutalistColor.muted)
    }

    private func categoryExtremesStrip(total: SGCardValues) -> some View {
        let ordered = orderedCategories(for: total)
        let worst = ordered.first ?? sgCategories[0]
        let best = ordered.last ?? sgCategories[0]
        return HStack(spacing: 0) {
            SGSummaryCell(
                label: "BIGGEST LEAK",
                title: worst.label,
                value: sgDecimalToDouble(total[keyPath: worst.totalsKeyPath]),
                short: nil
            )
            SGSummaryCell(
                label: "STRONGEST CATEGORY",
                title: best.label,
                value: sgDecimalToDouble(total[keyPath: best.totalsKeyPath]),
                short: nil,
                leadingBorder: true
            )
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        .padding(.top, 14)
    }

    private func orderedCategories(for total: SGCardValues) -> [SGCategorySpec] {
        sgCategories.sorted {
            sgDecimalToDouble(total[keyPath: $0.totalsKeyPath])
                < sgDecimalToDouble(total[keyPath: $1.totalsKeyPath])
        }
    }

    private func sgSplit(_ total: SGCardValues) -> (gained: Double, lost: Double) {
        sgCategories.reduce(into: (gained: 0.0, lost: 0.0)) { result, category in
            let value = sgDecimalToDouble(total[keyPath: category.totalsKeyPath])
            if value >= 0 {
                result.gained += value
            } else {
                result.lost += abs(value)
            }
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
