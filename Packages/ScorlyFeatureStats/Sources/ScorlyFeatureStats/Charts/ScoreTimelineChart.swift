import ScorlyDesignSystem
import SwiftUI

/// Score-vs-par timeline. One bar per round, anchored on the
/// horizontal par-axis. Under-par rounds grow *up* from the axis;
/// over-par rounds hang *down*. Even-par rounds register as a hairline
/// tick on the axis so the eye still has a beat in the sequence.
///
/// Pure paint via `Canvas`, no scrolling, no haptics — the whole story
/// is read at a glance. Color-mode flips for the inverse stamp.
struct ScoreTimelineChart: View {
    let values: [Int]
    /// Inverse mode draws against an ink ground (bone-cream paint).
    var inverse = false

    var body: some View {
        Canvas { ctx, size in
            guard !values.isEmpty else { return }
            // Symmetric axis. Floor at ±3 so a flat sample doesn't
            // explode visually and a single +9 doesn't dwarf the rest.
            let extremum = max(3, values.map { abs($0) }.max() ?? 0)
            let mid = size.height / 2
            let count = CGFloat(values.count)
            let gap: CGFloat = 2
            let barW = max(2.0, (size.width - gap * (count - 1)) / count)

            // Axis hairline.
            let axisPath = Path { p in
                p.move(to: CGPoint(x: 0, y: mid))
                p.addLine(to: CGPoint(x: size.width, y: mid))
            }
            ctx.stroke(axisPath, with: .color(axisColor), lineWidth: 1)

            // Bars
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * (barW + gap)
                if v == 0 {
                    // Tick on the axis itself for even par.
                    let rect = CGRect(x: x, y: mid - 1.5, width: barW, height: 3)
                    ctx.fill(Path(rect), with: .color(barColor))
                } else {
                    let magnitude = CGFloat(abs(v)) / CGFloat(extremum)
                    let h = max(2.0, magnitude * mid)
                    let rect: CGRect
                    if v < 0 {
                        // Under par: grow up from axis.
                        rect = CGRect(x: x, y: mid - h, width: barW, height: h)
                    } else {
                        // Over par: hang down from axis.
                        rect = CGRect(x: x, y: mid, width: barW, height: h)
                    }
                    ctx.fill(Path(rect), with: .color(barColor))
                }
            }
        }
        .frame(height: 84)
        .accessibilityLabel("Score versus par timeline")
        .accessibilityValue(
            "\(values.count) rounds, average \(String(format: "%.1f", avgValue))"
        )
    }

    private var avgValue: Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private var barColor: Color {
        inverse ? BrutalistColor.invFg : BrutalistColor.fg
    }

    private var axisColor: Color {
        inverse
            ? BrutalistColor.invFg.opacity(0.35)
            : BrutalistColor.fg.opacity(0.40)
    }
}
