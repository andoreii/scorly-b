import SwiftUI

/// Per-round hit-rate sample for the trend chart. Percentage is 0…1.
public struct AccuracyTrendPoint: Sendable, Equatable, Hashable {
    public let date: Date
    public let hitRate: Double

    public init(date: Date, hitRate: Double) {
        self.date = date
        self.hitRate = hitRate
    }
}

/// Accuracy card — hazard-coded windrose + 20-round hit-% line graph.
/// Covers both `.fairway` (FIR) and `.green` (GIR) via the same composition.
/// Color is reserved for hazard tiers + trend indicator; rest is ink-on-bone.
public struct AccuracyTrendCard: View {
    private let kind: AccuracyRoseKind
    private let values: AccuracyRoseValues
    private let trend: [AccuracyTrendPoint]
    private let courseCount: Int

    public init(
        kind: AccuracyRoseKind,
        values: AccuracyRoseValues,
        trend: [AccuracyTrendPoint],
        courseCount: Int
    ) {
        self.kind = kind
        self.values = values
        self.trend = trend
        self.courseCount = courseCount
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.bg
            CornerMarks(size: 8, inset: 6)
            VStack(alignment: .leading, spacing: 0) {
                header
                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(height: 1)
                    .padding(.top, 12)
                windroseBlock
                    .padding(.top, 14)
                heroBlock
                    .padding(.top, 6)
                hazardLegend
                    .padding(.top, 12)
                Rectangle()
                    .fill(BrutalistColor.hair)
                    .frame(height: 1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)
                lineChartHeader
                    .padding(.bottom, 6)
                AccuracyHitLineChart(points: trend)
                    .frame(height: 200)
                footer
                    .padding(.top, 8)
            }
            .padding(18)
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACCURACY · LAST \(trend.count) ROUNDS")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                    .lineLimit(1)
                Text(kind.title)
                    .font(BrutalistType.sans(.bold, size: 22))
                    .kerning(-0.6)
                    .foregroundStyle(BrutalistColor.fg)
            }
            Spacer()
            trendIndicator
        }
    }

    @ViewBuilder
    private var trendIndicator: some View {
        if let delta = trendDelta {
            let improving = delta >= 0
            let color: Color = improving ? BrutalistColor.sgPos : BrutalistColor.sgNeg
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(improving ? "↗" : "↘") \(improving ? "IMPROVING" : "DECLINING")")
                    .font(BrutalistType.mono(.semibold, size: 13))
                    .kerning(0.4)
                    .foregroundStyle(color)
                    .lineLimit(1)
                Text(deltaLabel(delta))
                    .font(BrutalistType.mono(.medium, size: 9))
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
                    .lineLimit(1)
            }
        }
    }

    /// Delta (pts) between mean of last 5 and first 5 hit-rates. nil until 10+ rounds.
    private var trendDelta: Double? {
        guard trend.count >= 10 else { return nil }
        let recent = trend.suffix(5).map(\.hitRate)
        let first = trend.prefix(5).map(\.hitRate)
        let r = recent.reduce(0, +) / 5
        let f = first.reduce(0, +) / 5
        return (r - f) * 100
    }

    private func deltaLabel(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : "−"
        return "\(sign)\(Int(abs(delta).rounded())) PTS VS FIRST 5"
    }

    // MARK: - Windrose

    private var windroseBlock: some View {
        HStack {
            Spacer(minLength: 0)
            AccuracyWindrose(values: values)
                .frame(maxWidth: 256)
                .aspectRatio(1, contentMode: .fit)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Hero hit %

    private var heroBlock: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(heroNumber)
                    .font(BrutalistType.mono(.semibold, size: 44))
                    .kerning(-1.8)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                Text("%")
                    .font(BrutalistType.mono(.semibold, size: 18))
                    .foregroundStyle(BrutalistColor.muted)
            }
            Text(kind.hitLabel)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroNumber: String {
        guard let rate = values.hitRate else { return "—" }
        return "\(Int((rate * 100).rounded()))"
    }

    // MARK: - Hazard legend

    private var hazardLegend: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            hazardChip(color: AccuracyHazardPalette.rough, label: "ROUGH")
            hazardChip(color: AccuracyHazardPalette.bunker, label: "BUNKER")
            hazardChip(color: AccuracyHazardPalette.ob, label: "OB")
            Spacer(minLength: 0)
        }
    }

    private func hazardChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 11, height: 11)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            Text(label)
                .font(BrutalistType.mono(.medium, size: 9))
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    // MARK: - Line chart

    private var lineChartHeader: some View {
        HStack {
            Text("HIT % · PER ROUND")
                .font(BrutalistType.mono(.semibold, size: 10))
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
            Spacer()
            Text("\(kind.kickerUpper) · \(trend.count) RND")
                .font(BrutalistType.mono(.medium, size: 9))
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(dateLabel(trend.first?.date))
            Spacer()
            Text("\(trend.count) ROUNDS · \(courseCount) COURSE\(courseCount == 1 ? "" : "S")")
            Spacer()
            Text(dateLabel(trend.last?.date))
        }
        .font(BrutalistType.mono(.medium, size: 9))
        .kerning(0.6)
        .foregroundStyle(BrutalistColor.dim)
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "—" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "dd MMM yy"
        return fmt.string(from: date).uppercased()
    }
}

// MARK: - AccuracyRoseKind additions

extension AccuracyRoseKind {
    var kickerUpper: String {
        switch self {
        case .fairway: "FAIRWAY"
        case .green: "GREEN"
        }
    }

    var hitLabel: String {
        switch self {
        case .fairway: "FAIRWAYS HIT"
        case .green: "GREENS HIT"
        }
    }
}

// MARK: - Hazard palette

/// Hazard palette encoding where a missed shot ended (rough / bunker / OB).
/// Scoped here, not promoted to BrutalistColor since these aren't reusable semantic tokens.
enum AccuracyHazardPalette {
    static let rough = Color(red: 0x8A / 255, green: 0x87 / 255, blue: 0x80 / 255)
    static let bunker = Color(red: 0xC9 / 255, green: 0xA8 / 255, blue: 0x6B / 255)
    static let ob = Color(red: 0xB2 / 255, green: 0x3A / 255, blue: 0x2E / 255)
    static let bunkerText = Color(red: 0x9C / 255, green: 0x7A / 255, blue: 0x33 / 255)
}

// MARK: - Windrose

/// Four-sector hazard-stacked windrose. Disc radius scales with hit rate;
/// each sector grows outward with miss share, stacked rough→bunker→OB.
private struct AccuracyWindrose: View {
    let values: AccuracyRoseValues

    /// Compass-style directions, 0° = up, clockwise. Empty sectors just don't draw.
    private struct Sector {
        let direction: AccuracyRoseValues.Direction
        let word: String
        let centerAngle: Double
    }

    private static let sectors: [Sector] = [
        Sector(direction: .long, word: "LONG", centerAngle: 0),
        Sector(direction: .right, word: "RIGHT", centerAngle: 90),
        Sector(direction: .short, word: "SHORT", centerAngle: 180),
        Sector(direction: .left, word: "LEFT", centerAngle: 270)
    ]

    /// Geometry constants scaled to canvas side length, matching the 240px design reference.
    private struct Geometry {
        let center: CGPoint
        let r0: CGFloat      // disc zone radius
        let labelR: CGFloat  // ring where direction labels sit
        let maxOuter: CGFloat
        let halfAngle: Double

        init(side: CGFloat) {
            let ref: CGFloat = 240
            let scale = side / ref
            center = CGPoint(x: side / 2, y: side / 2)
            r0 = 28 * scale
            labelR = 100 * scale
            maxOuter = 74 * scale
            halfAngle = 27
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let geo = Geometry(side: side)
            ZStack {
                Canvas { ctx, _ in
                    drawGuides(ctx: &ctx, geo: geo)
                    drawSectors(ctx: &ctx, geo: geo)
                    drawDisc(ctx: &ctx, geo: geo)
                }
                ForEach(Self.sectors, id: \.word) { sector in
                    directionLabel(for: sector, geo: geo)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    // MARK: - Drawing

    private func drawGuides(ctx: inout GraphicsContext, geo: Geometry) {
        let outer = Path(
            ellipseIn: CGRect(
                x: geo.center.x - geo.maxOuter,
                y: geo.center.y - geo.maxOuter,
                width: geo.maxOuter * 2,
                height: geo.maxOuter * 2
            )
        )
        ctx.stroke(outer, with: .color(BrutalistColor.hair), lineWidth: 0.6)
        let inner = Path(
            ellipseIn: CGRect(
                x: geo.center.x - geo.r0,
                y: geo.center.y - geo.r0,
                width: geo.r0 * 2,
                height: geo.r0 * 2
            )
        )
        ctx.stroke(
            inner,
            with: .color(BrutalistColor.dim),
            style: StrokeStyle(lineWidth: 0.8, dash: [2, 2.5])
        )
    }

    private func drawSectors(ctx: inout GraphicsContext, geo: Geometry) {
        // Normalise against the loudest direction so the rose balances even with small totals.
        let totals = Self.sectors.map { stack(for: $0.direction).total }
        let maxTotal = max(totals.max() ?? 0, 1)
        let range = geo.maxOuter - geo.r0
        for sector in Self.sectors {
            let m = stack(for: sector.direction)
            let normalised = CGFloat(m.total) / CGFloat(maxTotal)
            let length = normalised * range
            guard length > 0.3 else { continue }
            let a1 = sector.centerAngle - geo.halfAngle
            let a2 = sector.centerAngle + geo.halfAngle
            // Stack rough → bunker → OB outward. Water folds into OB (both penalty strokes).
            let stacks: [(count: Int, color: Color)] = [
                (m.clean, AccuracyHazardPalette.rough),
                (m.bunker, AccuracyHazardPalette.bunker),
                (m.ob + m.water, AccuracyHazardPalette.ob)
            ]
            var travelled: CGFloat = 0
            for layer in stacks where layer.count > 0 {
                let span = length * CGFloat(layer.count) / CGFloat(max(m.total, 1))
                let r1 = geo.r0 + travelled
                let r2 = r1 + span
                let path = sectorPath(center: geo.center, r1: r1, r2: r2, a1: a1, a2: a2)
                ctx.fill(path, with: .color(layer.color))
                ctx.stroke(path, with: .color(BrutalistColor.bg), lineWidth: 0.9)
                travelled += span
            }
        }
    }

    private func drawDisc(ctx: inout GraphicsContext, geo: Geometry) {
        let rate = max(0, min(1, values.hitRate ?? 0))
        let r = max(6 * geo.r0 / 28, (geo.r0 - 2) * CGFloat(rate))
        let rect = CGRect(
            x: geo.center.x - r,
            y: geo.center.y - r,
            width: r * 2,
            height: r * 2
        )
        ctx.fill(Path(ellipseIn: rect), with: .color(BrutalistColor.fg))
    }

    // MARK: - Direction labels

    @ViewBuilder
    private func directionLabel(for sector: Sector, geo: Geometry) -> some View {
        let m = stack(for: sector.direction)
        let allTot = max(Self.sectors.map { stack(for: $0.direction).total }.reduce(0, +), 1)
        let sharePct = Int(((Double(m.total) / Double(allTot)) * 100).rounded())
        let bkPct = Int(((Double(m.bunker) / Double(allTot)) * 100).rounded())
        let obPct = Int(((Double(m.ob + m.water) / Double(allTot)) * 100).rounded())
        VStack(spacing: 1) {
            Text(sector.word)
                .font(BrutalistType.mono(.medium, size: 7.5))
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
            Text("\(sharePct)%")
                .font(BrutalistType.mono(.semibold, size: 12))
                .monospacedDigit()
                .foregroundStyle(BrutalistColor.fg)
            HStack(spacing: 6) {
                Text("\(bkPct)%")
                    .foregroundStyle(AccuracyHazardPalette.bunkerText)
                Text("\(obPct)%")
                    .foregroundStyle(AccuracyHazardPalette.ob)
            }
            .font(BrutalistType.mono(.semibold, size: 7.5))
            .monospacedDigit()
        }
        .position(labelPosition(for: sector, geo: geo))
    }

    private func labelPosition(for sector: Sector, geo: Geometry) -> CGPoint {
        let rad = sector.centerAngle * .pi / 180
        let x = geo.center.x + geo.labelR * CGFloat(sin(rad))
        let y = geo.center.y - geo.labelR * CGFloat(cos(rad))
        return CGPoint(x: x, y: y)
    }

    // MARK: - Geometry helpers

    private func stack(for direction: AccuracyRoseValues.Direction)
        -> AccuracyRoseValues.DirectionStack
    {
        values.byDirection[direction] ?? .init()
    }

    /// Annular sector as two ring arcs joined by radial lines. Compass-degree
    /// inputs converted to math angles (0° = east, +CCW) for `Path.addArc`.
    private func sectorPath(
        center: CGPoint,
        r1: CGFloat,
        r2: CGFloat,
        a1: Double,
        a2: Double
    ) -> Path {
        var path = Path()
        let mathStart = Angle(degrees: a1 - 90)
        let mathEnd = Angle(degrees: a2 - 90)
        let outerStart = polar(compass: a1, radius: r2, center: center)
        let innerEnd = polar(compass: a2, radius: r1, center: center)
        path.move(to: outerStart)
        path.addArc(
            center: center,
            radius: r2,
            startAngle: mathStart,
            endAngle: mathEnd,
            clockwise: false
        )
        path.addLine(to: innerEnd)
        path.addArc(
            center: center,
            radius: r1,
            startAngle: mathEnd,
            endAngle: mathStart,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    private func polar(compass degrees: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let rad = degrees * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(sin(rad)),
            y: center.y - radius * CGFloat(cos(rad))
        )
    }
}

// MARK: - Hit-% line chart

/// Single-series line chart: solid ink stroke, hollow dots (last one filled),
/// right-edge numeric tag, dashed gridlines every 10 percentage points.
private struct AccuracyHitLineChart: View {
    let points: [AccuracyTrendPoint]

    var body: some View {
        Canvas { ctx, size in
            guard !points.isEmpty else { return }
            let values = points.map { $0.hitRate * 100 }
            let lo = values.min() ?? 0
            let hi = values.max() ?? 100
            let yMin = max(0, (floor((lo - 8) / 10)) * 10)
            let yMax = min(100, (ceil((hi + 8) / 10)) * 10)

            let padL: CGFloat = 30
            let padR: CGFloat = 40
            let padT: CGFloat = 12
            let padB: CGFloat = 24
            let iw = size.width - padL - padR
            let ih = size.height - padT - padB
            let denom = max(CGFloat(points.count - 1), 1)
            let xFor: (Int) -> CGFloat = { i in padL + iw * CGFloat(i) / denom }
            let yFor: (Double) -> CGFloat = { v in
                padT + ih * CGFloat(1 - (v - yMin) / max(yMax - yMin, 1))
            }

            // Y-grid every 10 ticks.
            for t in stride(from: Int(yMin), through: Int(yMax), by: 10) {
                let y = yFor(Double(t))
                var p = Path()
                p.move(to: CGPoint(x: padL, y: y))
                p.addLine(to: CGPoint(x: size.width - padR, y: y))
                ctx.stroke(
                    p,
                    with: .color(BrutalistColor.hair),
                    style: StrokeStyle(lineWidth: 0.6, dash: [2, 3])
                )
                let label = Text("\(t)")
                    .font(BrutalistType.mono(.medium, size: 9))
                    .foregroundStyle(BrutalistColor.muted)
                ctx.draw(label, at: CGPoint(x: padL - 6, y: y), anchor: .trailing)
            }

            // Line.
            var line = Path()
            for (i, v) in values.enumerated() {
                let p = CGPoint(x: xFor(i), y: yFor(v))
                if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            ctx.stroke(
                line,
                with: .color(BrutalistColor.fg),
                style: StrokeStyle(lineWidth: 1.9, lineJoin: .round)
            )

            // Dots hollow except the last, which fills solid so the eye snaps to "now".
            for (i, v) in values.enumerated() {
                let isLast = i == values.count - 1
                let r: CGFloat = isLast ? 3.4 : 2.2
                let rect = CGRect(
                    x: xFor(i) - r,
                    y: yFor(v) - r,
                    width: r * 2,
                    height: r * 2
                )
                let dot = Path(ellipseIn: rect)
                ctx.fill(dot, with: .color(isLast ? BrutalistColor.fg : BrutalistColor.bg))
                ctx.stroke(dot, with: .color(BrutalistColor.fg), lineWidth: 1.3)
            }

            // Right-edge tag on the most recent value.
            if let last = values.last {
                let tagText = Text("\(Int(last.rounded()))%")
                    .font(BrutalistType.mono(.semibold, size: 10))
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                let tagPos = CGPoint(
                    x: size.width - padR + 6,
                    y: yFor(last)
                )
                ctx.draw(tagText, at: tagPos, anchor: .leading)
            }

            // X labels at first / middle / last.
            if points.count >= 2 {
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "en_US_POSIX")
                fmt.dateFormat = "dd MMM"
                let idxs = [0, points.count / 2, points.count - 1]
                for (k, i) in idxs.enumerated() {
                    let raw = fmt.string(from: points[i].date).uppercased()
                    let label = Text(raw)
                        .font(BrutalistType.mono(.medium, size: 9))
                        .kerning(0.4)
                        .foregroundStyle(BrutalistColor.muted)
                    let anchor: UnitPoint = k == 0 ? .leading
                        : k == idxs.count - 1 ? .trailing
                        : .center
                    ctx.draw(label, at: CGPoint(x: xFor(i), y: size.height - 7), anchor: anchor)
                }
            }
        }
    }
}
