import ScorlyDesignSystem
import SwiftUI

/// Penalty heatmap. One small square per round in the sample window
/// (chronological, left → right), ink density proportional to the
/// effective penalty stroke count on that round. A clean round leaves
/// a hollow cell; a wreck punches through as solid ink.
struct PenaltyGrid: View {
    /// Penalty counts in chronological order (oldest → newest).
    let values: [Int]
    /// Max in the window; used as the denominator. Drawing with a
    /// soft floor of 2 so a single‑penalty cell still reads as
    /// "something happened" rather than nothing.
    let cap: Int

    /// Grid columns. 10 reads as a single dense ledger row for the
    /// LAST‑10 window and two clean rows for LAST‑20.
    private let columns = 10

    var body: some View {
        let rows = max(1, Int(ceil(Double(values.count) / Double(columns))))
        let safeCap = max(2, cap)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < values.count {
                            cell(for: values[index], cap: safeCap)
                        } else {
                            // Empty slot — keeps the grid square,
                            // shown as a soft hairline placeholder.
                            cell(for: nil, cap: safeCap)
                        }
                    }
                }
            }
        }
    }

    private func cell(for value: Int?, cap: Int) -> some View {
        let size: CGFloat = 22
        let opacity: Double = {
            guard let value, value > 0 else { return 0 }
            // Map 1…cap into 0.30…1.0 so a single penalty still
            // registers visually but doesn't shout.
            let ratio = Double(min(value, cap)) / Double(cap)
            return 0.30 + 0.70 * ratio
        }()
        return ZStack {
            Rectangle()
                .fill(BrutalistColor.fg.opacity(opacity))
            // Hairline outline so empty cells still draw the grid.
            Rectangle()
                .stroke(BrutalistColor.rule, lineWidth: 1)
            if let value, value > 0 {
                Text("\(value)")
                    .font(BrutalistType.mono(.semibold, size: 9))
                    .monospacedDigit()
                    .foregroundStyle(
                        opacity > 0.55 ? BrutalistColor.invFg : BrutalistColor.fg
                    )
            }
        }
        .frame(width: size, height: size)
    }
}
