import ScorlyDesignSystem
import SwiftUI

/// Single horizontal divergent bar. Anchored on a center zero axis.
/// Positive values extend right (gain); negative left (loss).
///
/// Used by the Strokes Gained breakdown — four of these stacked share
/// the same `extremum` so the eye can compare categories without
/// re-normalising mentally.
struct DivergentBar: View {
    let label: String
    let value: Double
    /// Symmetric axis half-range. All bars in a stack should use the
    /// same value so comparisons across rows are honest.
    let extremum: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                Text(formatted)
                    .font(BrutalistType.mono(.semibold, size: 13))
                    .kerning(0.4)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
            }
            track
        }
    }

    private var track: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let mid = width / 2
            let safeExtremum = max(0.0001, extremum)
            let magnitude = CGFloat(min(abs(value) / safeExtremum, 1))
            let barW = magnitude * mid
            ZStack(alignment: .leading) {
                // Track outline.
                Rectangle()
                    .stroke(BrutalistColor.rule, lineWidth: 1)
                // Center axis hairline.
                Rectangle()
                    .fill(BrutalistColor.rule)
                    .frame(width: 1)
                    .offset(x: mid)
                // The bar itself.
                Rectangle()
                    .fill(BrutalistColor.fg)
                    .frame(width: max(0, barW), height: 18)
                    .offset(x: value >= 0 ? mid : mid - barW)
            }
        }
        .frame(height: 18)
    }

    private var formatted: String {
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.2f", abs(value)))"
    }
}
