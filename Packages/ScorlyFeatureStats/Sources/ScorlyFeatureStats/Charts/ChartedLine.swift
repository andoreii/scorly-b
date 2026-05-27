import ScorlyDesignSystem
import SwiftUI

/// Taller cousin of `Sparkline`. Same single-stroke ink line + dashed
/// mean baseline + endpoint marker as the original, but at chart
/// scale (default 96pt) with a two-line "AVG" label anchored top-left
/// so the magnitude is readable without the surrounding parent
/// having to display the same number elsewhere.
///
/// Format of the label adapts to the series kind:
///   - `.percent`  →  "58%"   (FIR / GIR / 3-putt rate when expressed as a rate)
///   - `.decimal`  →  "32.1"  (avg putts per round, average 3-putts per round)
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
            // Background sparkline canvas, identical drawing logic to
            // `Sparkline` but at full height.
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

                // Dashed mean baseline so the value rendered in the
                // AVG label has a visual anchor on the chart.
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
            // Top-left two-line label so the magnitude reads at a
            // glance even without a separate caption next to the
            // chart.
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
        // Inset top by ~30pt so the AVG label has room without
        // colliding with the line.
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
