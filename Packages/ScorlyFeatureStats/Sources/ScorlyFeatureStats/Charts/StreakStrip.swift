import ScorlyDesignSystem
import SwiftUI

/// Hot/cold streak strip. One cell per round in chronological order.
/// Each cell renders the round's vs-par result in the scorecard
/// notation vocabulary:
///
///   under par → bone cell, ink-circled mono number (good)
///   even par  → bone cell, plain mono number
///   over par  → inverse cell (ink ground, bone mono number), the
///               "bogey" square spirit
///
/// The strip reads as a 20-cell ticker — pattern visible at a
/// glance, exact magnitude legible on demand.
struct StreakStrip: View {
    /// vs-par values, oldest → newest.
    let values: [Int]

    private let cellSize: CGFloat = 30

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    cell(for: v)
                }
            }
        }
    }

    private func cell(for v: Int) -> some View {
        let isOver = v > 0
        let isUnder = v < 0
        let text = v >= 0 ? "+\(v)" : "\(v)"
        return ZStack {
            Rectangle()
                .fill(isOver ? BrutalistColor.fg : BrutalistColor.bg)
            Rectangle()
                .stroke(BrutalistColor.rule, lineWidth: 1)
            if isUnder {
                Circle()
                    .stroke(BrutalistColor.fg, lineWidth: 1)
                    .padding(4)
            }
            Text(text)
                .font(BrutalistType.mono(.semibold, size: 10))
                .kerning(0.4)
                .monospacedDigit()
                .foregroundStyle(isOver ? BrutalistColor.invFg : BrutalistColor.fg)
        }
        .frame(width: cellSize, height: cellSize)
    }
}
