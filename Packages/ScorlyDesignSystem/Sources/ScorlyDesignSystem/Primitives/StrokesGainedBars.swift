import SwiftUI

/// 4-row diverging category bars with optional ghost markers for the
/// season average. Internal to the design system; used by
/// `StrokesGainedCard`.
struct SGDivergingBars: View {
    let values: SGCardValues
    let seasonAverages: SGCardValues?
    let density: SGBreakdownDensity
    var categories = sgCategories
    var scaleMax = 3.0
    private let labelColumn: CGFloat = 120

    private var tickRange: [Int] {
        Array(stride(from: -Int(scaleMax), through: Int(scaleMax), by: 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: density.rowSpacing) {
            header
            if density.showsHeaderDivider {
                Rectangle()
                    .fill(BrutalistColor.fg)
                    .frame(height: 1)
            }
            ForEach(Array(categories.enumerated()), id: \.offset) { index, cat in
                categoryRow(for: cat, isLast: index == categories.count - 1)
            }
        }
    }

    @ViewBuilder private var header: some View {
        if density.usesStackedRows {
            stackedAxisHeader
        } else {
            inlineAxisHeader
        }
    }

    private var inlineAxisHeader: some View {
        HStack(spacing: 0) {
            Text("CATEGORY")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
                .frame(width: labelColumn, alignment: .leading)
            axisTicks
            Text("STROKES")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: density.valueColumnWidth, alignment: .trailing)
        }
        .padding(.bottom, density.axisHeaderBottomPadding)
    }

    private var stackedAxisHeader: some View {
        HStack {
            Text("CATEGORY")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            Spacer()
            Text("STROKES")
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
        }
        .padding(.bottom, density.axisHeaderBottomPadding)
    }

    private var axisTicks: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ForEach(tickRange, id: \.self) { tick in
                    let pct = (Double(tick) + scaleMax) / (scaleMax * 2)
                    Text(tick > 0 ? "+\(tick)" : "\(tick)")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.4)
                        .foregroundStyle(tick == 0 ? BrutalistColor.fg : BrutalistColor.muted)
                        .position(x: geo.size.width * pct, y: 7)
                }
            }
        }
        .frame(height: 14)
        .padding(.horizontal, density.trackHorizontalPadding)
    }

    @ViewBuilder
    private func categoryRow(for cat: SGCategorySpec, isLast: Bool) -> some View {
        if density.usesStackedRows {
            stackedRow(for: cat, isLast: isLast)
        } else {
            inlineRow(for: cat, isLast: isLast)
        }
    }

    private func inlineRow(for cat: SGCategorySpec, isLast: Bool) -> some View {
        let value = sgDecimalToDouble(values[keyPath: cat.totalsKeyPath])
        let avg: Double? = seasonAverages.map { sgDecimalToDouble($0[keyPath: cat.totalsKeyPath]) }
        return HStack(spacing: 0) {
            categoryLabel(for: cat)
                .frame(width: labelColumn, alignment: .leading)
                .padding(.trailing, density.labelTrailingPadding)
            track(value: value, seasonAvg: avg)
                .frame(height: density.trackHeight)
                .padding(.horizontal, density.trackHorizontalPadding)
                .frame(maxWidth: .infinity)
            valueLabel(for: cat, value: value)
                .frame(width: density.valueColumnWidth, alignment: .trailing)
        }
        .frame(height: density.rowHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isLast ? BrutalistColor.fg : BrutalistColor.hair)
                .frame(height: 1)
        }
    }

    private func stackedRow(for cat: SGCategorySpec, isLast: Bool) -> some View {
        let value = sgDecimalToDouble(values[keyPath: cat.totalsKeyPath])
        let avg: Double? = seasonAverages.map { sgDecimalToDouble($0[keyPath: cat.totalsKeyPath]) }
        return VStack(alignment: .leading, spacing: BrutalistSpacing.xxs) {
            HStack(alignment: .bottom) {
                categoryLabel(for: cat)
                Spacer(minLength: BrutalistSpacing.m)
                valueLabel(for: cat, value: value)
            }
            track(value: value, seasonAvg: avg)
                .frame(height: density.trackHeight)
                .padding(.horizontal, density.trackHorizontalPadding)
            if density.repeatsAxisTicksPerRow {
                axisTicks
            }
        }
        .frame(
            height: density.rowHeight + (isLast ? density.finalRowBottomPadding : 0),
            alignment: .top
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isLast ? BrutalistColor.fg : BrutalistColor.hair)
                .frame(height: 1)
        }
    }

    private func categoryLabel(for cat: SGCategorySpec) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if density.showsCategoryCodes {
                Text(cat.short)
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
            }
            Text(cat.label)
                .font(BrutalistType.sans(.semibold, size: 12))
                .foregroundStyle(BrutalistColor.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func valueLabel(for cat: SGCategorySpec, value: Double) -> some View {
        Text(sgFormat(values[keyPath: cat.totalsKeyPath]))
            .font(BrutalistType.mono(.semibold, size: 16))
            .monospacedDigit()
            .foregroundStyle(barColor(for: value))
    }

    private func track(value: Double, seasonAvg: Double?) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let zeroX = width * 0.5
            let valuePct = (sgClamp(value, -scaleMax, scaleMax) + scaleMax) / (scaleMax * 2)
            let valueX = width * valuePct
            let isPos = value > 0
            let barLeft = min(valueX, zeroX)
            let barWidth = max(abs(valueX - zeroX), 0)
            ZStack(alignment: .topLeading) {
                ForEach(tickRange, id: \.self) { tick in
                    gridline(tick: tick, width: width, height: height)
                }
                if value != 0 {
                    barSegment(isPos: isPos, barLeft: barLeft, barWidth: barWidth, height: height)
                    endCap(isPos: isPos, valueX: valueX, height: height)
                }
                if let seasonAvg {
                    seasonGhost(seasonAvg: seasonAvg, width: width, height: height)
                }
            }
        }
    }

    private func gridline(tick: Int, width: CGFloat, height: CGFloat) -> some View {
        let pct = (Double(tick) + scaleMax) / (scaleMax * 2)
        return Rectangle()
            .fill(tick == 0 ? BrutalistColor.fg : BrutalistColor.hair.opacity(0.6))
            .frame(width: 1, height: height)
            .offset(x: width * pct - 0.5, y: 0)
    }

    private func barSegment(isPos: Bool, barLeft: CGFloat, barWidth: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(isPos ? BrutalistColor.sgPosFill : BrutalistColor.sgNegFill)
            .frame(width: barWidth, height: max(height - 8, 1))
            .overlay(Rectangle().stroke(isPos ? BrutalistColor.sgPos : BrutalistColor.sgNeg, lineWidth: 1))
            .offset(x: barLeft, y: 4)
    }

    private func endCap(isPos: Bool, valueX: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(isPos ? BrutalistColor.sgPos : BrutalistColor.sgNeg)
            .frame(width: 2, height: height)
            .offset(x: valueX - 1, y: 0)
    }

    private func seasonGhost(seasonAvg: Double, width: CGFloat, height: CGFloat) -> some View {
        let avgPct = (sgClamp(seasonAvg, -scaleMax, scaleMax) + scaleMax) / (scaleMax * 2)
        let avgX = width * avgPct
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(BrutalistColor.muted.opacity(0.7))
                .frame(width: 1, height: height + 4)
                .offset(x: avgX - 0.5, y: -2)
            Circle()
                .fill(BrutalistColor.bg)
                .frame(width: 5, height: 5)
                .overlay(Circle().stroke(BrutalistColor.muted, lineWidth: 1))
                .offset(x: avgX - 2.5, y: -2)
        }
    }

    private func barColor(for value: Double) -> Color {
        if value == 0 { return BrutalistColor.muted }
        return value > 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg
    }
}

/// Compact single-round variant of the Trends card's category bars.
/// Each track keeps the center-axis treatment and optional season
/// marker while ordering categories from worst to best.
struct SGTrendDivergingBars: View {
    let values: SGCardValues
    let seasonAverages: SGCardValues?
    let categories: [SGCategorySpec]
    var scaleMax = 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(categories.enumerated()), id: \.offset) { _, category in
                SGTrendDivergingRow(
                    category: category,
                    value: sgDecimalToDouble(values[keyPath: category.totalsKeyPath]),
                    seasonAverage: seasonAverages.map {
                        sgDecimalToDouble($0[keyPath: category.totalsKeyPath])
                    },
                    scaleMax: scaleMax
                )
            }
        }
    }
}

private struct SGTrendDivergingRow: View {
    let category: SGCategorySpec
    let value: Double
    let seasonAverage: Double?
    let scaleMax: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category.label)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                Text(sgFormat(Decimal(value)))
                    .font(BrutalistType.mono(.semibold, size: 14))
                    .kerning(0.4)
                    .monospacedDigit()
                    .foregroundStyle(value >= 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg)
            }
            track
        }
    }

    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let midpoint = width / 2
            let safeScale = max(0.0001, scaleMax)
            let magnitude = CGFloat(min(abs(value) / safeScale, 1))
            let barWidth = magnitude * midpoint
            ZStack(alignment: .leading) {
                Rectangle()
                    .stroke(BrutalistColor.rule, lineWidth: 1)
                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(width: 1)
                    .offset(x: midpoint)
                Rectangle()
                    .fill(value >= 0 ? BrutalistColor.sgPos.opacity(0.18) : BrutalistColor.sgNeg.opacity(0.16))
                    .frame(width: max(0, barWidth), height: 30)
                    .overlay(Rectangle().stroke(value >= 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg, lineWidth: 1))
                    .offset(x: value >= 0 ? midpoint : midpoint - barWidth)
                if let seasonAverage {
                    seasonMarker(value: seasonAverage, midpoint: midpoint)
                }
            }
        }
        .frame(height: 30)
    }

    private func seasonMarker(value: Double, midpoint: CGFloat) -> some View {
        let magnitude = CGFloat(min(abs(value) / max(0.0001, scaleMax), 1))
        let x = value >= 0 ? midpoint + magnitude * midpoint : midpoint - magnitude * midpoint
        return Circle()
            .fill(BrutalistColor.bg)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(BrutalistColor.muted, lineWidth: 1))
            .offset(x: x - 3.5, y: 11.5)
    }
}
