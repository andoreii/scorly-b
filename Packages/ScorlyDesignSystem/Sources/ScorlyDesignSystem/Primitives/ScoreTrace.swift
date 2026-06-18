import SwiftUI

/// One round on the score-trace chart. Carries date + score + par
/// so the chart can draw the par reference line and label rounds
/// without a second pass.
public struct ScoreTracePoint: Sendable, Equatable, Hashable {
    public let date: Date
    public let score: Int
    public let par: Int

    public init(date: Date, score: Int, par: Int) {
        self.date = date
        self.score = score
        self.par = par
    }
}

// MARK: - Chart primitive

/// Score-vs-par line graph. One solid ink stroke through every round,
/// a single dashed par reference line, and (optionally) a thin dotted
/// 5-round rolling average overlay. Y-ticks every 2 strokes; x-labels
/// at the four anchor positions (first, ~1/3, ~2/3, last).
///
/// Points must be supplied oldest → newest.
public struct ScoreTraceChart: View {
    let points: [ScoreTracePoint]
    let showAxis: Bool
    let showRollingAvg: Bool
    let showParLine: Bool
    let drawTrigger: Int
    let drawDelay: Double?
    @State private var drawStartedAt: Date?
    @State private var isDrawing = false
    @State private var hasCompletedDraw: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let drawDuration = 0.72

    public init(
        points: [ScoreTracePoint],
        showAxis: Bool = true,
        showRollingAvg: Bool = false,
        showParLine: Bool = true,
        drawTrigger: Int = 0,
        drawDelay: Double? = nil
    ) {
        self.points = points
        self.showAxis = showAxis
        self.showRollingAvg = showRollingAvg
        self.showParLine = showParLine
        self.drawTrigger = drawTrigger
        self.drawDelay = drawDelay
        _hasCompletedDraw = State(initialValue: drawDelay == nil)
    }

    public var body: some View {
        TimelineView(.animation(paused: !isDrawing)) { timeline in
            Canvas { ctx, size in
                guard points.count >= 1 else { return }
                let draw = currentDrawProgress(at: timeline.date)
                let scores = points.map { Double($0.score) }
                let pars = points.map { Double($0.par) }
                let lo = min(scores.min() ?? 70, pars.min() ?? 70)
                let hi = max(scores.max() ?? 90, pars.max() ?? 90)
                let yMin = lo - 2
                let yMax = hi + 2

                let padL: CGFloat = showAxis ? 30 : 8
                let padR: CGFloat = 10
                let padT: CGFloat = 14
                let padB: CGFloat = showAxis ? 26 : 12
                let iw = size.width - padL - padR
                let ih = size.height - padT - padB
                let denom = max(CGFloat(points.count - 1), 1)
                let xFor: (Int) -> CGFloat = { idx in padL + iw * CGFloat(idx) / denom }
                let yFor: (Double) -> CGFloat = { v in
                    padT + ih * CGFloat(1 - (v - yMin) / (yMax - yMin))
                }

                // 1) Y-grid: dashed hairline every 2 strokes.
                let lowTick = Int((yMin / 2).rounded(.up)) * 2
                let highTick = Int(yMax)
                for t in stride(from: lowTick, through: highTick, by: 2) {
                    let y = yFor(Double(t))
                    var p = Path()
                    p.move(to: CGPoint(x: padL, y: y))
                    p.addLine(to: CGPoint(x: size.width - padR, y: y))
                    ctx.stroke(
                        p,
                        with: .color(BrutalistColor.hair),
                        style: StrokeStyle(lineWidth: 0.6, dash: [2, 3])
                    )
                    if showAxis {
                        let label = Text("\(t)")
                            .font(BrutalistType.mono(.medium, size: 9))
                            .foregroundStyle(BrutalistColor.muted)
                        ctx.draw(label, at: CGPoint(x: padL - 5, y: y), anchor: .trailing)
                    }
                }

                // 2) Par reference line — single dashed horizontal at the
                //    most common par. Most rounds are par-72; if pars vary
                //    the line still gives the eye a stable anchor.
                if showParLine {
                    let parRef = modePar(of: points.map(\.par))
                    let parY = yFor(Double(parRef))
                    var line = Path()
                    line.move(to: CGPoint(x: padL, y: parY))
                    line.addLine(to: CGPoint(x: size.width - padR, y: parY))
                    ctx.stroke(
                        line,
                        with: .color(BrutalistColor.muted),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    let tag = Text("PAR \(parRef)")
                        .font(BrutalistType.mono(.medium, size: 8))
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                    ctx.draw(tag, at: CGPoint(x: size.width - padR - 2, y: parY - 7), anchor: .trailing)
                }

                // 3) 5-round rolling average — thin dotted ink overlay.
                if showRollingAvg, points.count >= 2 {
                    let avg = rollingAvg(scores, window: 5)
                    let path = progressiveLinePath(
                        points: avg.enumerated().map { i, v in CGPoint(x: xFor(i), y: yFor(v)) },
                        progress: draw
                    )
                    ctx.stroke(
                        path,
                        with: .color(BrutalistColor.muted),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                    )
                }

                // 4) Score line — solid ink, primary.
                let scorePoints = scores.enumerated().map { i, s in CGPoint(x: xFor(i), y: yFor(s)) }
                let scoreLine = progressiveLinePath(points: scorePoints, progress: draw)
                ctx.stroke(
                    scoreLine,
                    with: .color(BrutalistColor.fg),
                    style: StrokeStyle(lineWidth: 1.8, lineJoin: .round)
                )

                // 5) Per-round dots. Hollow bone with ink ring; the last
                //    round flips to solid ink so the latest reads as the
                //    current state.
                let visibleDotCount = draw.visibleDotCount(totalPoints: scores.count)
                for i in scores.indices.prefix(visibleDotCount) {
                    let cx = xFor(i)
                    let cy = yFor(scores[i])
                    let last = i == scores.count - 1
                    let r: CGFloat = last ? 3.6 : 2.6
                    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                    let ring = Path(ellipseIn: rect)
                    ctx.fill(ring, with: .color(last ? BrutalistColor.fg : BrutalistColor.bg))
                    ctx.stroke(ring, with: .color(BrutalistColor.fg), lineWidth: 1.4)
                }

                // 6) X-axis date labels at four anchor positions.
                if showAxis, points.count >= 2 {
                    let idxs = [
                        0,
                        points.count / 3,
                        (points.count * 2) / 3,
                        points.count - 1,
                    ]
                    let fmt = DateFormatter()
                    fmt.locale = Locale(identifier: "en_US_POSIX")
                    fmt.dateFormat = "dd MMM"
                    for (k, i) in idxs.enumerated() {
                        let raw = fmt.string(from: points[i].date).uppercased()
                        let label = Text(raw)
                            .font(BrutalistType.mono(.medium, size: 9))
                            .kerning(0.4)
                            .foregroundStyle(BrutalistColor.muted)
                        let anchor: UnitPoint = k == 0 ? .leading
                            : k == idxs.count - 1 ? .trailing
                            : .center
                        ctx.draw(label, at: CGPoint(x: xFor(i), y: size.height - 8), anchor: anchor)
                    }
                }
            }
        }
        .task(id: drawTrigger) {
            await drawLine()
        }
    }

    private func modePar(of pars: [Int]) -> Int {
        guard !pars.isEmpty else { return 72 }
        var counts: [Int: Int] = [:]
        for p in pars {
            counts[p, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? pars[0]
    }

    private func rollingAvg(_ arr: [Double], window: Int) -> [Double] {
        arr.indices.map { i in
            let start = max(0, i - window + 1)
            let slice = arr[start...i]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private func progressiveLinePath(points: [CGPoint], progress: ScoreTraceDrawProgress) -> Path {
        guard points.count >= 2, progress.value > 0 else { return Path() }
        let segmentCount = points.count - 1
        let scaledProgress = progress.value * Double(segmentCount)
        let completeSegments = min(Int(scaledProgress.rounded(.down)), segmentCount)
        let partialProgress = scaledProgress - Double(completeSegments)

        var path = Path()
        path.move(to: points[0])

        if completeSegments > 0 {
            for index in 1...completeSegments {
                path.addLine(to: points[index])
            }
        }

        if completeSegments < segmentCount, partialProgress > 0 {
            let start = points[completeSegments]
            let end = points[completeSegments + 1]
            path.addLine(to: CGPoint(
                x: start.x + (end.x - start.x) * partialProgress,
                y: start.y + (end.y - start.y) * partialProgress
            ))
        }

        return path
    }

    private func currentDrawProgress(at date: Date) -> ScoreTraceDrawProgress {
        guard !reduceMotion, !hasCompletedDraw else { return ScoreTraceDrawProgress(1) }
        guard let drawStartedAt else { return ScoreTraceDrawProgress(0) }
        return ScoreTraceDrawProgress.elapsed(
            date.timeIntervalSince(drawStartedAt),
            duration: Self.drawDuration
        )
    }

    @MainActor
    private func drawLine() async {
        guard let drawDelay, !reduceMotion else {
            hasCompletedDraw = true
            isDrawing = false
            drawStartedAt = nil
            return
        }

        hasCompletedDraw = false
        isDrawing = false
        drawStartedAt = nil

        try? await Task.sleep(for: .seconds(drawDelay))
        guard !Task.isCancelled else { return }

        drawStartedAt = Date()
        isDrawing = true

        try? await Task.sleep(for: .seconds(Self.drawDuration))
        guard !Task.isCancelled else { return }

        hasCompletedDraw = true
        isDrawing = false
        drawStartedAt = nil
    }
}

struct ScoreTraceDrawProgress: Equatable {
    let value: Double

    init(_ value: Double) {
        self.value = min(max(value, 0), 1)
    }

    static func initial(drawDelay: Double?) -> ScoreTraceDrawProgress {
        ScoreTraceDrawProgress(drawDelay == nil ? 1 : 0)
    }

    static func elapsed(_ elapsed: Double, duration: Double) -> ScoreTraceDrawProgress {
        guard duration > 0 else { return ScoreTraceDrawProgress(1) }
        return ScoreTraceDrawProgress(elapsed / duration)
    }

    func visibleDotCount(totalPoints: Int) -> Int {
        guard totalPoints > 0, value > 0 else { return 0 }
        guard value < 1 else { return totalPoints }
        let segmentCount = max(totalPoints - 1, 1)
        return min(totalPoints, Int((value * Double(segmentCount)).rounded(.down)) + 1)
    }
}

// MARK: - History card (compact)

/// Compact score-trace card. Pinned above the History list. Surfaces
/// the latest score + a small Avg/Best stack, then the line graph,
/// then a one-line legend.
public struct ScoreTraceHistoryCard: View {
    let points: [ScoreTracePoint]

    public init(points: [ScoreTracePoint]) {
        self.points = points
    }

    public var body: some View {
        if points.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        let scores = points.map { Double($0.score) }
        let last = points.last!
        let lastDiff = last.score - last.par
        let bestDiff = points.map { $0.score - $0.par }.min() ?? 0
        let avg = scores.reduce(0, +) / Double(scores.count)
        let delta = trailingDelta(of: scores, window: 3)

        return ZStack(alignment: .topLeading) {
            BrutalistColor.bg
            CornerMarks(size: 6, inset: 4)
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("SCORE · LAST \(points.count) ROUNDS")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.muted)
                    Spacer()
                    if let d = delta {
                        Text("\(arrow(for: d)) \(signed(d, places: 1)) L3 VS P3")
                            .font(BrutalistType.mono(.semibold, size: 9))
                            .kerning(0.8)
                            .foregroundStyle(perfColor(d))
                    }
                }
                .padding(.bottom, 10)

                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(height: 1)
                    .padding(.bottom, 8)

                // Latest + Avg + Best
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LATEST")
                            .font(BrutalistType.monoMicro)
                            .kerning(0.8)
                            .foregroundStyle(BrutalistColor.muted)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(last.score)")
                                .font(BrutalistType.sans(.bold, size: 40))
                                .kerning(-1.4)
                                .monospacedDigit()
                                .lineLimit(1)
                            Text("\(signed(lastDiff)) · PAR \(last.par)")
                                .font(BrutalistType.mono(.medium, size: 11))
                                .kerning(0.4)
                                .foregroundStyle(BrutalistColor.muted)
                                .monospacedDigit()
                        }
                    }
                    Spacer()
                    HStack(alignment: .top, spacing: 14) {
                        cornerStat(label: "AVG", value: String(format: "%.1f", avg))
                        cornerStat(label: "BEST", value: signed(bestDiff))
                    }
                }
                .padding(.bottom, 6)

                // Chart
                ScoreTraceChart(
                    points: points,
                    showAxis: true,
                    showRollingAvg: false,
                    showParLine: true
                )
                .frame(height: 160)

                // Legend
                HStack {
                    HStack(spacing: 14) {
                        legendItem(symbol: .solid, label: "SCORE")
                        legendItem(symbol: .dashed, label: "PAR")
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(BrutalistColor.fg)
                            .frame(width: 7, height: 7)
                        Text("LATEST ROUND")
                            .font(BrutalistType.mono(.medium, size: 9))
                            .kerning(0.6)
                            .foregroundStyle(BrutalistColor.muted)
                    }
                }
                .padding(.top, 6)
            }
            .padding(14)
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func cornerStat(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            Text(value)
                .font(BrutalistType.mono(.semibold, size: 16))
                .monospacedDigit()
                .foregroundStyle(BrutalistColor.fg)
        }
    }
}

// MARK: - Trends card (hero)

/// Hero score-trace card for the Trends tab. Title + AVG-vs-par
/// readout up top, a 3-cell KPI strip (last 20 avg, best, form),
/// then the full chart with rolling-average overlay, then a date
/// footer.
struct ScoreTraceTrendsSummary {
    let averageLabel: String
    let average: Double?

    init(scores: [Int]) {
        let count = min(scores.count, 20)
        averageLabel = "LAST \(count) AVG"
        guard count > 0 else {
            average = nil
            return
        }
        average = Double(scores.suffix(count).reduce(0, +)) / Double(count)
    }
}

public enum ScoreTraceTrendsCardMode {
    case full
    case dashboard
}

private struct ScoreTraceDirectionArrow: Shape {
    let pointsUp: Bool

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let xOffset = rect.midX - 12 * scale
        let yOffset = rect.midY - 12 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: xOffset + x * scale, y: yOffset + y * scale)
        }

        var path = Path()
        if pointsUp {
            path.move(to: point(4.5, 19.5))
            path.addLine(to: point(19.5, 4.5))
            path.move(to: point(19.5, 4.5))
            path.addLine(to: point(8.25, 4.5))
            path.move(to: point(19.5, 4.5))
            path.addLine(to: point(19.5, 15.75))
        } else {
            path.move(to: point(4.5, 4.5))
            path.addLine(to: point(19.5, 19.5))
            path.move(to: point(19.5, 19.5))
            path.addLine(to: point(19.5, 8.25))
            path.move(to: point(19.5, 19.5))
            path.addLine(to: point(8.25, 19.5))
        }
        return path
    }
}

enum ScoreTraceAverageTrend: Equatable {
    case improving
    case worsening

    init?(delta: Double?) {
        guard let delta, delta != 0 else {
            return nil
        }
        self = delta < 0 ? .improving : .worsening
    }

    var pointsUp: Bool {
        switch self {
        case .improving:
            false
        case .worsening:
            true
        }
    }

    var label: String {
        switch self {
        case .improving:
            "IMPROVING"
        case .worsening:
            "WORSENING"
        }
    }

    var color: Color {
        switch self {
        case .improving:
            BrutalistColor.sgPos
        case .worsening:
            BrutalistColor.sgNeg
        }
    }
}

public struct ScoreTraceTrendsCard: View {
    let points: [ScoreTracePoint]
    /// Distinct course count for the footer. Caller computes from the
    /// underlying round set so the card stays UI-only.
    let courseCount: Int
    private let mode: ScoreTraceTrendsCardMode
    private let graphDrawTrigger: Int
    private let graphDrawDelay: Double?

    public init(
        points: [ScoreTracePoint],
        courseCount: Int,
        mode: ScoreTraceTrendsCardMode = .full,
        graphDrawTrigger: Int = 0,
        graphDrawDelay: Double? = nil
    ) {
        self.points = points
        self.courseCount = courseCount
        self.mode = mode
        self.graphDrawTrigger = graphDrawTrigger
        self.graphDrawDelay = graphDrawDelay
    }

    public var body: some View {
        if points.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        let scores = points.map { Double($0.score) }
        let diffs = points.map { Double($0.score - $0.par) }
        let avgDiff = diffs.reduce(0, +) / Double(diffs.count)
        let best = points.min(by: { ($0.score - $0.par) < ($1.score - $1.par) })!
        let summary = ScoreTraceTrendsSummary(scores: points.map(\.score))
        let dashboardWindow = min(5, points.count)
        let dashboardAverage = scores.suffix(dashboardWindow).reduce(0, +) / Double(dashboardWindow)
        let trendDelta = trailingDelta(of: scores, window: 5)
        let averageTrend = ScoreTraceAverageTrend(delta: trendDelta)
        let avgVsParText = signed(avgDiff, places: 1)

        return ZStack(alignment: .topLeading) {
            BrutalistColor.bg
            CornerMarks(size: 8, inset: 6)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("SCORING · LAST \(points.count) ROUNDS")
                            .font(BrutalistType.monoLabel)
                            .kerning(1.0)
                            .foregroundStyle(BrutalistColor.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 6)
                        Text("AVG VS PAR")
                            .font(BrutalistType.mono(.medium, size: 9))
                            .kerning(0.8)
                            .foregroundStyle(BrutalistColor.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Score trend")
                            .font(BrutalistType.sans(.bold, size: 28))
                            .kerning(-1.0)
                            .foregroundStyle(BrutalistColor.fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 6)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            AnimatedNumericText(
                                value: avgVsParText,
                                trigger: graphDrawTrigger,
                                delay: graphDrawDelay ?? 0
                            )
                            .font(BrutalistType.sans(.bold, size: 38))
                            .kerning(-1.4)
                            .foregroundStyle(BrutalistColor.fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        }
                    }
                }

                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(height: 1)
                    .padding(.top, mode == .dashboard ? 10 : 12)

                // KPI strip
                HStack(spacing: 0) {
                    kpi(
                        label: mode == .dashboard ? "LAST 5 AVG" : summary.averageLabel,
                        value: mode == .dashboard
                            ? String(format: "%.1f", dashboardAverage)
                            : summary.average.map { String(format: "%.1f", $0) } ?? "—",
                        valueArrowPointsUp: averageTrend?.pointsUp,
                        valueArrowColor: averageTrend?.color,
                        valueArrowAccessibilityLabel: averageTrend?.label,
                        sub: trendDelta.map { "\(signed($0, places: 1)) VS PREV 5" },
                        subColor: trendDelta.map(perfColor) ?? BrutalistColor.muted,
                        border: false
                    )
                    kpi(
                        label: "BEST",
                        value: "\(best.score)",
                        sub: nil,
                        subColor: BrutalistColor.muted,
                        border: true
                    )
                    kpi(
                        label: "FORM",
                        value: averageTrend?.label ?? "NORMAL",
                        valueColor: averageTrend?.color ?? BrutalistColor.muted,
                        sub: nil,
                        subColor: BrutalistColor.muted,
                        border: true
                    )
                }
                .overlay(
                    Rectangle()
                        .fill(BrutalistColor.rule)
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Chart header + chart
                HStack {
                    Text("PER ROUND")
                        .font(BrutalistType.mono(.semibold, size: 10))
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.fg)
                    Spacer()
                    Text("── SCORE   ─ ─ PAR   ⋯ 5-RND AVG")
                        .font(BrutalistType.mono(.medium, size: 9))
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .padding(.top, 14)
                .padding(.bottom, 6)

                ScoreTraceChart(
                    points: points,
                    showAxis: true,
                    showRollingAvg: true,
                    showParLine: true,
                    drawTrigger: graphDrawTrigger,
                    drawDelay: graphDrawDelay
                )
                .frame(height: mode == .dashboard ? 300 : 240)

                if mode == .full {
                    // Footer
                    HStack {
                        Text(monthYear(points.first!.date))
                        Spacer()
                        Text("\(points.count) ROUNDS · \(courseCount) COURSE\(courseCount == 1 ? "" : "S")")
                        Spacer()
                        Text(monthYear(points.last!.date))
                    }
                    .font(BrutalistType.mono(.medium, size: 9))
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.dim)
                    .padding(.top, 10)
                }
            }
            .padding(mode == .dashboard ? 12 : 16)
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func kpi(
        label: String,
        value: String,
        valueColor: Color = BrutalistColor.fg,
        valueArrowPointsUp: Bool? = nil,
        valueArrowColor: Color? = nil,
        valueArrowAccessibilityLabel: String? = nil,
        sub: String?,
        subColor: Color,
        border: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            HStack(alignment: .center, spacing: 4) {
                AnimatedNumericText(
                    value: value,
                    trigger: graphDrawTrigger,
                    delay: graphDrawDelay ?? 0
                )
                .font(BrutalistType.mono(.semibold, size: 18))
                .foregroundStyle(valueColor)
                if let valueArrowPointsUp {
                    ScoreTraceDirectionArrow(pointsUp: valueArrowPointsUp)
                        .stroke(
                            valueArrowColor ?? valueColor,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 17, height: 17)
                        .accessibilityLabel(valueArrowAccessibilityLabel ?? "")
                }
            }
            .padding(.top, 4)
            if let sub {
                Text(sub)
                    .font(BrutalistType.mono(.medium, size: 9))
                    .kerning(0.4)
                    .foregroundStyle(subColor)
                    .padding(.top, 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle()
                .fill(BrutalistColor.hair)
                .frame(width: border ? 1 : 0),
            alignment: .leading
        )
    }
}

// MARK: - Shared helpers

private enum LegendSymbol { case solid, dashed }

private func legendItem(symbol: LegendSymbol, label: String) -> some View {
    HStack(spacing: 6) {
        switch symbol {
        case .solid:
            Rectangle()
                .fill(BrutalistColor.fg)
                .frame(width: 14, height: 1.6)
        case .dashed:
            DashedLine()
                .stroke(BrutalistColor.muted, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(width: 14, height: 1)
        }
        Text(label)
            .font(BrutalistType.mono(.medium, size: 9))
            .kerning(0.6)
            .foregroundStyle(BrutalistColor.muted)
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.midY
        p.move(to: CGPoint(x: rect.minX, y: y))
        p.addLine(to: CGPoint(x: rect.maxX, y: y))
        return p
    }
}

private func signed(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
}

private func signed(_ value: Double, places: Int) -> String {
    let fmt = "%+.\(places)f"
    return String(format: fmt, value)
}

private func perfColor(_ delta: Double) -> Color {
    if delta == 0 { return BrutalistColor.muted }
    return delta < 0 ? BrutalistColor.sgPos : BrutalistColor.sgNeg
}

private func arrow(for delta: Double) -> String {
    if delta < 0 { return "↘" }
    if delta > 0 { return "↗" }
    return "→"
}

/// Mean of the trailing `window` samples, or nil if not enough data.
private func trailingMean(of values: [Double], window: Int) -> Double? {
    guard values.count >= window else { return nil }
    let slice = values.suffix(window)
    return slice.reduce(0, +) / Double(window)
}

/// Mean of trailing `window` minus mean of the `window` before that.
/// nil unless there are at least 2 × window samples.
private func trailingDelta(of values: [Double], window: Int) -> Double? {
    guard values.count >= window * 2 else { return nil }
    let recent = values.suffix(window)
    let prior = values.dropLast(window).suffix(window)
    let r = recent.reduce(0, +) / Double(window)
    let p = prior.reduce(0, +) / Double(window)
    return r - p
}

private func monthDay(_ d: Date) -> String {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "dd MMM"
    return fmt.string(from: d).uppercased()
}

private func monthYear(_ d: Date) -> String {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "dd MMM yy"
    return fmt.string(from: d).uppercased()
}
