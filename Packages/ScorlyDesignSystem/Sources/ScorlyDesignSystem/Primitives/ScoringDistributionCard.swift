import SwiftUI

public struct ScoringDistributionCard: View {
    private let counts: [ScoringOutcome: Int]
    private let total: Int
    private let donutThickness: CGFloat = 28
    private let gapDegrees = 1.5

    public init(counts: [ScoringOutcome: Int], total: Int) {
        self.counts = counts
        self.total = total
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReviewCardHeader(meta: "SCORING", title: "Distribution", trailing: "\(total) HOLES")
            HBar(vMargin: 0)
            donut
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .padding(.vertical, 14)
            HBar(vMargin: 2)
            ForEach(ScoringOutcome.allCases) { outcome in
                legendRow(outcome)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private var donut: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outerRadius = side / 2 - 4
            let innerRadius = outerRadius - donutThickness
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                Canvas { context, _ in
                    drawSegments(
                        in: &context,
                        center: center,
                        innerRadius: innerRadius,
                        outerRadius: outerRadius
                    )
                }
                VStack(spacing: 4) {
                    Text("\(total)")
                        .font(BrutalistType.sans(.bold, size: 38))
                        .kerning(-1.4)
                        .monospacedDigit()
                    Text("HOLES")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                }
            }
        }
    }

    private func legendRow(_ outcome: ScoringOutcome) -> some View {
        let count = counts[outcome] ?? 0
        let share = total > 0 ? Double(count) / Double(total) : 0
        return HStack(spacing: 10) {
            Rectangle()
                .fill(color(for: outcome))
                .frame(width: 14, height: 14)
                .overlay(Rectangle().stroke(BrutalistColor.fg, lineWidth: 0.6))
            Text(outcome.label)
                .font(BrutalistType.monoCaption)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(count)")
                .font(BrutalistType.mono(.semibold, size: 12))
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)
            Text("\(Int((share * 100).rounded()))%")
                .font(BrutalistType.monoMicro)
                .kerning(0.4)
                .foregroundStyle(BrutalistColor.dim)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    private func drawSegments(
        in context: inout GraphicsContext,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) {
        guard total > 0 else {
            context.fill(
                annularSector(
                    center: center,
                    innerRadius: innerRadius,
                    outerRadius: outerRadius,
                    startAngle: 0,
                    endAngle: 360
                ),
                with: .color(BrutalistColor.panel)
            )
            return
        }
        let active = ScoringOutcome.allCases.filter { (counts[$0] ?? 0) > 0 }
        let sweepAvailable = 360 - Double(active.count) * gapDegrees
        var cursor = -90.0
        for outcome in active {
            let sweep = sweepAvailable * Double(counts[outcome] ?? 0) / Double(total)
            let path = annularSector(
                center: center,
                innerRadius: innerRadius,
                outerRadius: outerRadius,
                startAngle: cursor,
                endAngle: cursor + sweep
            )
            context.fill(path, with: .color(color(for: outcome)))
            context.stroke(path, with: .color(BrutalistColor.fg), lineWidth: 0.6)
            cursor += sweep + gapDegrees
        }
    }

    private func color(for outcome: ScoringOutcome) -> Color {
        switch outcome {
        case .birdiePlus: BrutalistColor.sgPos
        case .par: BrutalistColor.sgPosFill
        case .bogey: BrutalistColor.bogeyFill
        case .doublePlus: BrutalistColor.sgNeg
        }
    }

    private func annularSector(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startAngle: Double,
        endAngle: Double
    ) -> Path {
        var path = Path()
        let start = Angle(degrees: startAngle)
        let end = Angle(degrees: endAngle)
        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addLine(to: CGPoint(
            x: center.x + cos(endAngle * .pi / 180) * innerRadius,
            y: center.y + sin(endAngle * .pi / 180) * innerRadius
        ))
        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}
