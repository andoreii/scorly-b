import ScorlyDesignSystem
import SwiftUI

/// 20-rounds × 18-holes heat grid. Each cell colors by score vs par
/// using the shared 4-bucket vocabulary (birdie+, par, bogey, double+),
/// with a quiet `panel` fill for missing-data cells. Always pulls the
/// last 20 completed rounds regardless of the aggregate filter, padding
/// with placeholder rows when fewer rounds exist.
struct HoleHeatGrid: View {
    let rows: [HoleHeatRow]
    /// Total rows the grid always shows, padded with placeholders.
    private let rowCount = 20

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd MMM"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(meta: "SCORING", title: "Recent rounds", trailing: "LAST 20")
            HBar(vMargin: 0)
                .padding(.bottom, 4)
            headerRow
            ForEach(0..<rowCount, id: \.self) { rowIndex in
                if rowIndex < rows.count {
                    realRow(rows[rowIndex])
                } else {
                    placeholderRow
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func realRow(_ row: HoleHeatRow) -> some View {
        HStack(spacing: 4) {
            Text(Self.dateFormatter.string(from: row.date).uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
                .frame(width: 44, alignment: .leading)
            HStack(spacing: 1) {
                ForEach(Array(row.cells.enumerated()), id: \.offset) { index, cell in
                    heatCell(cell)
                    if index == 8 {
                        Rectangle()
                            .fill(BrutalistColor.hair)
                            .frame(width: 1, height: 14)
                    }
                }
            }
        }
    }

    private var placeholderRow: some View {
        HStack(spacing: 4) {
            Text("——")
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.dim)
                .frame(width: 44, alignment: .leading)
            HStack(spacing: 1) {
                ForEach(0..<18, id: \.self) { index in
                    Rectangle()
                        .fill(BrutalistColor.panel)
                        .frame(width: 14, height: 14)
                    if index == 8 {
                        Rectangle()
                            .fill(BrutalistColor.hair)
                            .frame(width: 1, height: 14)
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 4) {
            Text("DATE")
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.dim)
                .frame(width: 44, alignment: .leading)
            HStack(spacing: 1) {
                ForEach(0..<18, id: \.self) { i in
                    Text(String(i + 1))
                        .font(BrutalistType.monoMicro)
                        .kerning(0.4)
                        .foregroundStyle(BrutalistColor.dim)
                        .monospacedDigit()
                        .frame(width: 14, height: 12)
                    if i == 8 {
                        Rectangle()
                            .fill(BrutalistColor.hair)
                            .frame(width: 1, height: 8)
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func heatCell(_ cell: HoleHeatRow.Cell?) -> some View {
        let (fill, fg) = Self.colors(for: cell)
        return ZStack {
            Rectangle().fill(fill)
            if let cell {
                Text(String(cell.strokes))
                    .font(BrutalistType.monoLabel)
                    .kerning(0.2)
                    .monospacedDigit()
                    .foregroundStyle(fg)
            }
        }
        .frame(width: 14, height: 14)
    }

    /// Shared color mapping used by the distribution bars too.
    static func colors(for cell: HoleHeatRow.Cell?) -> (Color, Color) {
        guard let cell else { return (BrutalistColor.panel, BrutalistColor.muted) }
        switch HoleOutcome.outcome(forVsPar: cell.vsPar) {
        case .birdiePlus:
            return (BrutalistColor.sgPos, BrutalistColor.invFg)
        case .par:
            return (BrutalistColor.sgPosFill, BrutalistColor.fg)
        case .bogey:
            return (BrutalistColor.bogeyFill, BrutalistColor.fg)
        case .doublePlus:
            return (BrutalistColor.sgNeg, BrutalistColor.invFg)
        }
    }
}
