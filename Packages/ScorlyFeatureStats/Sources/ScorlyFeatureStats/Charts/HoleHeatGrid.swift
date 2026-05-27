import ScorlyDesignSystem
import SwiftUI

/// 20-rounds × 18-holes heat grid. Each cell colors by score vs par
/// using the shared 4-bucket vocabulary (birdie+, par, bogey, double+)
/// + a quiet `panel` for missing-data cells. Row labels are mono date
/// stamps; column header is the hole numbers with a soft rule between
/// front-9 and back-9. Always pulls the last 20 completed rounds — it
/// deliberately ignores the aggregate filter so the user has a stable
/// "what does my notebook look like" reference even while filtering.
///
/// When fewer than 20 rounds have been filed, the grid pads the
/// remainder with placeholder rows so the 20-row shape stays
/// consistent. Placeholders show an em-dash in the date column and
/// faint `panel` cells with no text — reads as "space reserved, not
/// yet played."
struct HoleHeatGrid: View {
    let rows: [HoleHeatRow]
    /// Total rows the grid should always show. Padded with
    /// placeholders below the real data when fewer have been logged.
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

    /// Single-source-of-truth color mapping shared with the
    /// distribution bars below.
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
