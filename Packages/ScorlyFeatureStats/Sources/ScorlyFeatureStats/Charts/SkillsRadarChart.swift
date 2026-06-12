import ScorlyDesignSystem
import SwiftUI

/// Eight-axis brutalist radar polygon, single series (windowed average).
/// Polygon/rings/spokes draw into a `Canvas`; axis labels render as
/// SwiftUI overlays so they aren't clipped by the polygon's bounding circle.
public struct SkillsRadarChart: View {
    public let axes: [RadarAxis]
    public var rings = 5

    public init(axes: [RadarAxis], rings: Int = 5) {
        self.axes = axes
        self.rings = rings
    }

    public var body: some View {
        GeometryReader { proxy in
            let geom = Geometry(size: proxy.size, axisCount: axes.count, rings: rings)
            ZStack {
                Canvas { context, _ in
                    var ctx = context
                    drawRings(in: &ctx, geom: geom)
                    drawSpokes(in: &ctx, geom: geom)
                    drawWindowPolygon(in: &ctx, geom: geom)
                    drawVertexDots(in: &ctx, geom: geom)
                    drawCenterCrosshair(in: &ctx, geom: geom)
                }
                axisLabels(geom: geom)
            }
        }
    }

    // MARK: - Geometry

    /// Polygon centers in the frame, radius pegged to the shorter axis to stay round.
    private struct Geometry {
        let centerX: CGFloat
        let centerY: CGFloat
        let radius: CGFloat
        let labelRadius: CGFloat
        let axisCount: Int
        let rings: Int

        init(size: CGSize, axisCount: Int, rings: Int) {
            // labelRadius is the smaller of the vertical/horizontal caps so the
            // polygon fills whichever dimension is least constrained.
            let halfShort = min(size.width, size.height) / 2
            let centerX = size.width / 2
            let verticalCap = halfShort - 14
            let horizontalCap = centerX - 26 - 6
            self.centerX = centerX
            centerY = size.height / 2
            labelRadius = max(0, min(verticalCap, horizontalCap))
            radius = labelRadius - 28
            self.axisCount = axisCount
            self.rings = rings
        }

        func angle(_ index: Int) -> Double {
            -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(axisCount)
        }

        func point(_ index: Int, percent: Double) -> CGPoint {
            let ang = angle(index)
            let len = radius * (percent / 100)
            return CGPoint(
                x: centerX + CGFloat(cos(ang)) * len,
                y: centerY + CGFloat(sin(ang)) * len
            )
        }

        /// Position for an axis label overlay (outside the polygon).
        func labelPoint(_ index: Int) -> CGPoint {
            let ang = angle(index)
            return CGPoint(
                x: centerX + CGFloat(cos(ang)) * labelRadius,
                y: centerY + CGFloat(sin(ang)) * labelRadius
            )
        }
    }

    // MARK: - Canvas pieces

    private func drawRings(in context: inout GraphicsContext, geom: Geometry) {
        let hair = BrutalistColor.hair
        let panel = BrutalistColor.panel
        for ringIndex in 1...geom.rings {
            let pct = Double(ringIndex) / Double(geom.rings) * 100
            let path = polygonPath(geom: geom) { _ in pct }
            if ringIndex == geom.rings {
                context.fill(path, with: .color(panel))
                context.stroke(path, with: .color(hair), lineWidth: 1.2)
            } else {
                context.stroke(
                    path,
                    with: .color(hair),
                    style: StrokeStyle(lineWidth: 0.8, dash: [2, 3])
                )
            }
        }
    }

    private func drawSpokes(in context: inout GraphicsContext, geom: Geometry) {
        for axisIndex in 0..<geom.axisCount {
            let pos = geom.point(axisIndex, percent: 100)
            var path = Path()
            path.move(to: CGPoint(x: geom.centerX, y: geom.centerY))
            path.addLine(to: pos)
            context.stroke(
                path,
                with: .color(BrutalistColor.hair),
                style: StrokeStyle(lineWidth: 0.8, dash: [2, 3])
            )
        }
    }

    private func drawWindowPolygon(in context: inout GraphicsContext, geom: Geometry) {
        let path = polygonPath(geom: geom) { Double(axes[$0].windowValue) }
        context.fill(path, with: .color(BrutalistColor.fg.opacity(0.14)))
        context.stroke(
            path,
            with: .color(BrutalistColor.fg),
            style: StrokeStyle(lineWidth: 1.6, lineJoin: .round)
        )
    }

    private func drawVertexDots(in context: inout GraphicsContext, geom: Geometry) {
        for axisIndex in 0..<geom.axisCount {
            let windowPos = geom.point(axisIndex, percent: Double(axes[axisIndex].windowValue))
            let windowRect = CGRect(
                x: windowPos.x - 2.6,
                y: windowPos.y - 2.6,
                width: 5.2,
                height: 5.2
            )
            context.fill(Path(ellipseIn: windowRect), with: .color(BrutalistColor.fg))
        }
    }

    private func drawCenterCrosshair(in context: inout GraphicsContext, geom: Geometry) {
        let centerDot = CGRect(
            x: geom.centerX - 1.6,
            y: geom.centerY - 1.6,
            width: 3.2,
            height: 3.2
        )
        context.fill(Path(ellipseIn: centerDot), with: .color(BrutalistColor.fg))
    }

    // MARK: - SwiftUI label overlays

    /// Drives label/value ordering so the value chip points away from the polygon.
    private enum LabelPlacement { case top, bottom, side }

    private func axisLabels(geom: Geometry) -> some View {
        ForEach(Array(axes.enumerated()), id: \.element.id) { index, axis in
            let placement = labelPlacement(for: geom.angle(index))
            AxisLabelView(axis: axis, placement: placement)
                .fixedSize()
                .position(geom.labelPoint(index))
        }
    }

    private func labelPlacement(for angle: Double) -> LabelPlacement {
        let sine = sin(angle)
        // sin(-π/2) = -1 (top), sin(π/2) = 1 (bottom).
        if sine < -0.7 { return .top }
        if sine > 0.7 { return .bottom }
        return .side
    }

    private struct AxisLabelView: View {
        let axis: RadarAxis
        let placement: LabelPlacement

        var body: some View {
            VStack(spacing: 3) {
                if placement == .top {
                    // Value above label so the chip points up, away from the vertex.
                    value
                    label
                } else {
                    label
                    value
                }
            }
            .multilineTextAlignment(.center)
        }

        private var label: some View {
            Text(axis.polygonLabel)
                .font(BrutalistType.monoMicro)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
                .lineLimit(1)
        }

        private var value: some View {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(axis.windowValue)")
                    .monospacedDigit()
                if let arrow = axis.trendDirection.arrow {
                    Text(arrow)
                        .font(BrutalistType.mono(.medium, size: 9))
                }
            }
            .font(BrutalistType.mono(.semibold, size: 11))
            .kerning(0.4)
            .foregroundStyle(valueColor)
        }

        private var valueColor: Color {
            switch axis.trendDirection {
            case .up: BrutalistColor.sgPos
            case .down: BrutalistColor.sgNeg
            case .unchanged: BrutalistColor.fg
            }
        }
    }

    // MARK: - Helpers

    /// Closed polygon path from a percent provider (constant for rings, per-axis for series).
    private func polygonPath(
        geom: Geometry,
        percentForAxis: (Int) -> Double
    ) -> Path {
        var path = Path()
        for axisIndex in 0..<geom.axisCount {
            let pos = geom.point(axisIndex, percent: percentForAxis(axisIndex))
            if axisIndex == 0 {
                path.move(to: pos)
            } else {
                path.addLine(to: pos)
            }
        }
        path.closeSubpath()
        return path
    }
}
