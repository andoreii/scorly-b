import ScorlyDesignSystem
import SwiftUI

/// Taller cousin of `Sparkline` — same line + mean baseline + endpoint
/// marker, but at chart scale (default 96pt) with an "AVG" label
/// top-left so the magnitude reads without a separate caption.
struct ChartedLine: View {
    enum Format {
        case percent
        case decimal
    }

    let series: [Double]
    let format: Format
    var height: CGFloat = 96

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Same drawing logic as `Sparkline`, at full height.
            Canvas { ctx, size in
                guard series.count > 1 else {
                    if let last = series.last {
                        drawEndpoint(ctx: ctx, at: CGPoint(x: size.width - 4, y: size.height / 2))
                        _ = last
                    }
                    return
                }
                let minV = series.min() ?? 0
                let maxV = series.max() ?? 1
                let range = max(0.0001, maxV - minV)
                let mean = series.reduce(0, +) / Double(series.count)
                let step = size.width / CGFloat(series.count - 1)

                // Dashed baseline anchors the AVG label to the chart.
                let meanY = yFor(mean, minV: minV, range: range, size: size)
                var baseline = Path()
                baseline.move(to: CGPoint(x: 0, y: meanY))
                baseline.addLine(to: CGPoint(x: size.width, y: meanY))
                ctx.stroke(
                    baseline,
                    with: .color(BrutalistColor.fg.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                )

                // Line + endpoint.
                var path = Path()
                for (index, value) in series.enumerated() {
                    let xPos = CGFloat(index) * step
                    let yPos = yFor(value, minV: minV, range: range, size: size)
                    if index == 0 {
                        path.move(to: CGPoint(x: xPos, y: yPos))
                    } else {
                        path.addLine(to: CGPoint(x: xPos, y: yPos))
                    }
                }
                ctx.stroke(path, with: .color(BrutalistColor.fg), lineWidth: 1.4)
                if let last = series.last {
                    let xPos = size.width
                    let yPos = yFor(last, minV: minV, range: range, size: size)
                    drawEndpoint(ctx: ctx, at: CGPoint(x: xPos - 3, y: yPos))
                }
            }
            // Top-left two-line magnitude label.
            VStack(alignment: .leading, spacing: 2) {
                Text("AVG")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                Text(averageLabel)
                    .font(BrutalistType.sans(.bold, size: 22))
                    .kerning(-0.6)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
            }
            .padding(.leading, 2)
            .padding(.top, 2)
        }
        .frame(height: height)
    }

    private var averageLabel: String {
        guard !series.isEmpty else { return "—" }
        let mean = series.reduce(0, +) / Double(series.count)
        switch format {
        case .percent:
            return "\(Int((mean * 100).rounded()))%"
        case .decimal:
            return String(format: "%.1f", mean)
        }
    }

    private func yFor(_ value: Double, minV: Double, range: Double, size: CGSize) -> CGFloat {
        let norm = (value - minV) / range
        // Top inset leaves room for the AVG label.
        let topInset: CGFloat = 32
        let bottomInset: CGFloat = 6
        let padded = size.height - topInset - bottomInset
        return topInset + CGFloat(1 - norm) * padded
    }

    private func drawEndpoint(ctx: GraphicsContext, at point: CGPoint) {
        let size: CGFloat = 6
        let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        ctx.fill(Path(rect), with: .color(BrutalistColor.fg))
    }
}
