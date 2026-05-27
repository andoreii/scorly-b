import ScorlyDesignSystem
import SwiftUI

/// Score-by-round line graph for the fixed header. Y axis is the raw
/// total strokes for each round (80 / 82 / 85 …). The chart is built
/// from `ScoreLinePoint`s so it can also render month-zone labels
/// along the x-axis and per-point score callouts above each dot
/// without a second pass over the data.
///
/// Visual vocabulary:
/// - Soft hairline gridlines at each integer score between the
///   chart's min and max.
/// - Dashed mean line with an "AVG 82.2" mono tag pinned to the
///   right edge.
/// - Single ink stroke through every round; ink dot per point with
///   a tabular mono callout above it.
/// - Month-zone hairline ticks under the chart, labeled with the
///   month abbreviation under the centre of each zone.
struct ScoreVsParLine: View {
    let points: [ScoreLinePoint]

    private let yAxisWidth: CGFloat = 32
    private let monthZoneHeight: CGFloat = 18

    var body: some View {
        HStack(spacing: 6) {
            yAxis
                .frame(width: yAxisWidth)
            VStack(spacing: 4) {
                chart
                monthZones
                    .frame(height: monthZoneHeight)
            }
        }
    }

    // MARK: - Chart canvas

    private var chart: some View {
        Canvas { ctx, size in
            guard !points.isEmpty else { return }
            let bounds = chartBounds()
            let scores = points.map { Double($0.score) }
            // Inset the plotted region horizontally so the first /
            // last point dots and their numeric callouts don't get
            // clipped by the canvas edge. Mean tag at the right
            // also lives inside the inset.
            let hInset: CGFloat = 16
            let plotWidth = max(0, size.width - hInset * 2)
            let step: CGFloat = scores.count > 1
                ? plotWidth / CGFloat(scores.count - 1)
                : 0
            let xFor: (Int) -> CGFloat = { index in
                scores.count > 1
                    ? hInset + CGFloat(index) * step
                    : size.width / 2
            }
            let mean = scores.reduce(0, +) / Double(scores.count)

            // 1) Integer-value gridlines.
            for value in stride(
                from: Int(bounds.min.rounded()),
                through: Int(bounds.max.rounded()),
                by: 1
            ) {
                let yPos = yFor(Double(value), bounds: bounds, size: size)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: yPos))
                path.addLine(to: CGPoint(x: size.width, y: yPos))
                ctx.stroke(
                    path,
                    with: .color(BrutalistColor.hair.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 0.5)
                )
            }

            // 2) Mean line (heavier dash) + value tag at right edge.
            let meanY = yFor(mean, bounds: bounds, size: size)
            var meanLine = Path()
            meanLine.move(to: CGPoint(x: 0, y: meanY))
            meanLine.addLine(to: CGPoint(x: size.width, y: meanY))
            ctx.stroke(
                meanLine,
                with: .color(BrutalistColor.fg.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
            let meanText = Text("AVG \(String(format: "%.1f", mean))")
                .font(BrutalistType.monoMicro)
                .foregroundStyle(BrutalistColor.muted)
            // Tag sits just inside the inset so it never clips when
            // the last data dot is also near the right edge.
            ctx.draw(meanText, at: CGPoint(x: size.width - hInset, y: meanY - 8), anchor: .trailing)

            // 3) Score line.
            var line = Path()
            for (index, score) in scores.enumerated() {
                let xPos = xFor(index)
                let yPos = yFor(score, bounds: bounds, size: size)
                if index == 0 {
                    line.move(to: CGPoint(x: xPos, y: yPos))
                } else {
                    line.addLine(to: CGPoint(x: xPos, y: yPos))
                }
            }
            ctx.stroke(line, with: .color(BrutalistColor.fg), lineWidth: 1.6)

            // 4) Per-point dot. No numeric callout — the line speaks
            // for itself; the AVG tag at the right + the y-axis tick
            // rail carry the magnitude reference.
            for (index, score) in scores.enumerated() {
                let xPos = xFor(index)
                let yPos = yFor(score, bounds: bounds, size: size)
                let isLast = index == scores.count - 1
                let dotSize: CGFloat = isLast ? 7 : 4
                let rect = CGRect(
                    x: xPos - dotSize / 2,
                    y: yPos - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                if isLast {
                    ctx.fill(Path(rect), with: .color(BrutalistColor.fg))
                } else {
                    ctx.fill(Path(ellipseIn: rect), with: .color(BrutalistColor.fg))
                }
            }
        }
    }

    // MARK: - Y-axis labels

    private var yAxis: some View {
        let bounds = chartBounds()
        let inset: CGFloat = 6
        return VStack(alignment: .trailing, spacing: 0) {
            axisLabel(value: bounds.max)
            Spacer(minLength: 0)
            axisLabel(value: bounds.mid)
            Spacer(minLength: 0)
            axisLabel(value: bounds.min)
        }
        // Match the chart's vertical inset PLUS the month-zone row
        // we draw below so the top/mid/bottom labels align with the
        // chart's top/middle/bottom — not with the overall column.
        .padding(.top, inset)
        .padding(.bottom, inset + monthZoneHeight + 4)
    }

    private func axisLabel(value: Double) -> some View {
        Text("\(Int(value.rounded()))")
            .font(BrutalistType.monoMicro)
            .kerning(0.4)
            .foregroundStyle(BrutalistColor.dim)
            .monospacedDigit()
    }

    // MARK: - Month zones

    /// Hairline ticks separating months along the X axis, with a
    /// mono month abbreviation centred under each zone. Helps the
    /// reader anchor a stretch of rounds in time without having to
    /// stamp every point with a date.
    private var monthZones: some View {
        Canvas { ctx, size in
            guard !points.isEmpty else { return }
            let zones = computeMonthZones()
            guard !zones.isEmpty else { return }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMM"
            let count = max(1, points.count - 1)
            for zone in zones {
                let startFraction = CGFloat(zone.startIndex) / CGFloat(count)
                let endFraction = CGFloat(zone.endIndex) / CGFloat(count)
                let xStart = startFraction * size.width
                let xEnd = endFraction * size.width

                // Hairline tick at the start of each new month
                // except the first zone (which starts at x = 0).
                if zone.startIndex > 0 {
                    var tick = Path()
                    tick.move(to: CGPoint(x: xStart, y: 0))
                    tick.addLine(to: CGPoint(x: xStart, y: 6))
                    ctx.stroke(tick, with: .color(BrutalistColor.hair), lineWidth: 0.6)
                }

                let label = Text(formatter.string(from: zone.month).uppercased())
                    .font(BrutalistType.monoMicro)
                    .foregroundStyle(BrutalistColor.dim)
                let mid = (xStart + xEnd) / 2
                ctx.draw(label, at: CGPoint(x: mid, y: 10), anchor: .center)
            }
        }
    }

    // MARK: - Math

    private struct Bounds {
        let min: Double
        let max: Double
        var range: Double {
            max - min
        }

        var mid: Double {
            (min + max) / 2
        }
    }

    private func chartBounds() -> Bounds {
        guard !points.isEmpty else { return Bounds(min: 70, max: 90) }
        let values = points.map { Double($0.score) }
        let minValue = values.min() ?? 70
        let maxValue = values.max() ?? 90
        let padding: Double = max(2, (maxValue - minValue) * 0.15)
        return Bounds(min: floor(minValue - padding), max: ceil(maxValue + padding))
    }

    private func yFor(_ value: Double, bounds: Bounds, size: CGSize) -> CGFloat {
        guard bounds.range > 0 else { return size.height / 2 }
        let inset: CGFloat = 6
        let normalized = (value - bounds.min) / bounds.range
        let usable = size.height - inset * 2
        return inset + CGFloat(1 - normalized) * usable
    }

    /// Walk the points once to produce contiguous month-zones.
    /// Each zone records the first and last point index that falls
    /// into the same calendar month + year.
    private struct MonthZone {
        let month: Date
        let startIndex: Int
        let endIndex: Int
    }

    private func computeMonthZones() -> [MonthZone] {
        guard !points.isEmpty else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        var zones: [MonthZone] = []
        var currentMonth: Date?
        var currentStart = 0
        for (index, point) in points.enumerated() {
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: point.date)
            ) ?? point.date
            if let current = currentMonth, current != monthStart {
                zones.append(MonthZone(
                    month: current,
                    startIndex: currentStart,
                    endIndex: index - 1
                ))
                currentStart = index
            }
            currentMonth = monthStart
        }
        if let current = currentMonth {
            zones.append(MonthZone(
                month: current,
                startIndex: currentStart,
                endIndex: points.count - 1
            ))
        }
        return zones
    }
}
