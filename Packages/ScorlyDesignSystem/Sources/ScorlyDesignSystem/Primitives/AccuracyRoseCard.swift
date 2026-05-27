import SwiftUI

public enum AccuracyRoseKind: Sendable {
    case fairway
    case green

    var title: String {
        switch self {
        case .fairway: "Fairways"
        case .green: "Greens"
        }
    }

    var meta: String {
        switch self {
        case .fairway: "FAIRWAYS IN REG"
        case .green: "GREENS IN REG"
        }
    }

    var directions: [AccuracyRoseValues.Direction] {
        switch self {
        case .fairway: [.left, .right]
        case .green: AccuracyRoseValues.Direction.allCases
        }
    }
}

public struct AccuracyRoseCard<Footer: View>: View {
    private let kind: AccuracyRoseKind
    private let values: AccuracyRoseValues
    private let footer: Footer?

    public init(
        kind: AccuracyRoseKind,
        values: AccuracyRoseValues,
        @ViewBuilder footer: () -> Footer
    ) {
        self.kind = kind
        self.values = values
        self.footer = footer()
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.bg
            CornerMarks(size: 6, inset: 4)
            VStack(alignment: .leading, spacing: 12) {
                ReviewCardHeader(
                    meta: kind.meta,
                    title: kind.title,
                    trailing: "N=\(values.opportunities)"
                )
                AccuracyRosePlot(values: values, directions: kind.directions)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                if let footer {
                    Rectangle().fill(BrutalistColor.hair).frame(height: 1)
                    footer
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }
}

public extension AccuracyRoseCard where Footer == EmptyView {
    init(kind: AccuracyRoseKind, values: AccuracyRoseValues) {
        self.kind = kind
        self.values = values
        footer = nil
    }
}

private struct AccuracyRosePlot: View {
    let values: AccuracyRoseValues
    let directions: [AccuracyRoseValues.Direction]

    private let wedgeArcDegrees = 80.0
    private let bubbleGap: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let bubbleRadius = bubbleRadius(side: side)
            let outerRadius = side / 2 - 18
            let innerRadius = bubbleRadius + bubbleGap
            ZStack {
                Canvas { context, _ in
                    for direction in directions {
                        drawWedge(
                            direction: direction,
                            in: &context,
                            center: center,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius
                        )
                        drawTip(
                            direction: direction,
                            in: &context,
                            center: center,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius
                        )
                    }
                }
                hitBubble
                    .frame(width: bubbleRadius * 2, height: bubbleRadius * 2)
                    .position(center)
            }
        }
    }

    private var hitBubble: some View {
        ZStack {
            Circle().fill(BrutalistColor.sgPos.opacity(0.18))
            Circle().stroke(BrutalistColor.fg, lineWidth: 1)
            VStack(spacing: 0) {
                Text(percentLabel(values.hitRate))
                    .font(BrutalistType.sans(.bold, size: 24))
                    .kerning(-0.6)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                Text("HIT")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
            }
        }
    }

    private func drawWedge(
        direction: AccuracyRoseValues.Direction,
        in context: inout GraphicsContext,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) {
        let stack = values.byDirection[direction] ?? .init()
        let length = (outerRadius - innerRadius) * CGFloat(values.petalLength(for: direction))
        let angles = wedgeAngles(for: direction)
        guard length > 0 else {
            context.fill(
                annularSector(
                    center: center,
                    innerRadius: innerRadius,
                    outerRadius: innerRadius + 2,
                    startAngle: angles.start,
                    endAngle: angles.end
                ),
                with: .color(BrutalistColor.hair.opacity(0.4))
            )
            return
        }
        let segments: [(Int, Color)] = [
            (stack.clean, BrutalistColor.hair),
            (stack.bunker, BrutalistColor.panel2),
            (stack.water, BrutalistColor.sgNeg.opacity(0.5)),
            (stack.ob, BrutalistColor.sgNeg),
        ]
        var travelled: CGFloat = 0
        for segment in segments where segment.0 > 0 {
            let span = length * CGFloat(segment.0) / CGFloat(max(stack.total, 1))
            context.fill(
                annularSector(
                    center: center,
                    innerRadius: innerRadius + travelled,
                    outerRadius: innerRadius + travelled + span,
                    startAngle: angles.start,
                    endAngle: angles.end
                ),
                with: .color(segment.1)
            )
            travelled += span
        }
        context.stroke(
            annularSector(
                center: center,
                innerRadius: innerRadius,
                outerRadius: innerRadius + length,
                startAngle: angles.start,
                endAngle: angles.end
            ),
            with: .color(BrutalistColor.fg),
            lineWidth: 0.8
        )
    }

    private func drawTip(
        direction: AccuracyRoseValues.Direction,
        in context: inout GraphicsContext,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat
    ) {
        let ratio = values.petalLength(for: direction)
        guard ratio > 0.05 else { return }
        let length = (outerRadius - innerRadius) * CGFloat(ratio)
        let angles = wedgeAngles(for: direction)
        let radians = (angles.start + angles.end) / 2 * .pi / 180
        let point = CGPoint(
            x: center.x + cos(radians) * (innerRadius + length + 10),
            y: center.y + sin(radians) * (innerRadius + length + 10)
        )
        let text = Text("\(Int((values.percent(for: direction) * 100).rounded()))%")
            .font(BrutalistType.monoMicro)
            .foregroundStyle(BrutalistColor.fg)
        context.draw(text, at: point, anchor: .center)
    }

    private func bubbleRadius(side: CGFloat) -> CGFloat {
        let rate = values.hitRate ?? 0
        return max(32, max(side * 0.18, 32) * CGFloat(max(0.4, rate)))
    }

    private func percentLabel(_ rate: Double?) -> String {
        guard let rate, rate.isFinite else { return "-" }
        return "\(Int((rate * 100).rounded()))%"
    }

    private func wedgeAngles(for direction: AccuracyRoseValues.Direction) -> (start: Double, end: Double) {
        let center: Double = switch direction {
        case .right: 0
        case .short: 90
        case .left: 180
        case .long: 270
        }
        return (center - wedgeArcDegrees / 2, center + wedgeArcDegrees / 2)
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
