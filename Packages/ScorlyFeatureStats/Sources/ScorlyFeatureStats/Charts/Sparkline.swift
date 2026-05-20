import ScorlyDesignSystem
import SwiftUI

/// Tiny trend line. Auto-scales to its series' min/max, draws a
/// dashed baseline at the window mean, plots the line as a single
/// stroke, and caps the most recent point with a solid square. No
/// axis labels — this is a sparkline, the magnitude lives next to it
/// in the parent layout.
struct Sparkline: View {
    let series: [Double]

    var body: some View {
        Canvas { ctx, size in
            guard series.count > 1 else {
                // Single sample — just a dot in the middle.
                if let value = series.first {
                    drawDot(ctx: ctx, at: CGPoint(x: size.width - 4, y: size.height / 2))
                    _ = value
                }
                return
            }
            let minV = series.min() ?? 0
            let maxV = series.max() ?? 1
            let range = max(0.0001, maxV - minV)
            let mean = series.reduce(0, +) / Double(series.count)
            let step = size.width / CGFloat(series.count - 1)

            // Dashed mean baseline.
            let meanY = yFor(mean, minV: minV, range: range, size: size)
            let baseline = Path { p in
                p.move(to: CGPoint(x: 0, y: meanY))
                p.addLine(to: CGPoint(x: size.width, y: meanY))
            }
            ctx.stroke(
                baseline,
                with: .color(BrutalistColor.fg.opacity(0.25)),
                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
            )

            // Line path.
            var path = Path()
            for (i, v) in series.enumerated() {
                let x = CGFloat(i) * step
                let y = yFor(v, minV: minV, range: range, size: size)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .color(BrutalistColor.fg), lineWidth: 1.4)

            // Endpoint square.
            if let last = series.last {
                let x = size.width
                let y = yFor(last, minV: minV, range: range, size: size)
                drawDot(ctx: ctx, at: CGPoint(x: x - 3, y: y))
            }
        }
        .frame(height: 28)
    }

    private func yFor(_ v: Double, minV: Double, range: Double, size: CGSize) -> CGFloat {
        // Higher values draw higher on screen → flip.
        let norm = (v - minV) / range
        // Inset by 2px top/bottom so endpoint squares don't get
        // clipped by the surrounding hairline border.
        let padded = size.height - 4
        return 2 + CGFloat(1 - norm) * padded
    }

    private func drawDot(ctx: GraphicsContext, at point: CGPoint) {
        let s: CGFloat = 5
        let rect = CGRect(x: point.x - s / 2, y: point.y - s / 2, width: s, height: s)
        ctx.fill(Path(rect), with: .color(BrutalistColor.fg))
    }
}
