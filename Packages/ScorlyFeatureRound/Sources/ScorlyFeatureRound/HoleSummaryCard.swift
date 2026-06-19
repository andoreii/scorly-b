import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Live hole summary that sits above the Thread: the running score and
/// to-par label, then FIR / GIR / Putts / Pen cells. Mirrors the React
/// `RPIHoleSummary`. Reads everything from `RoundPlayState.summaryStats`
/// so it stays in lock-step with the logged shots.
struct HoleSummaryCard: View {
    let hole: Hole
    let stats: HoleSummaryStats
    let done: Bool

    private var toParText: String {
        guard let score = stats.score else { return "E" }
        let delta = score - hole.par
        return delta == 0 ? "E" : delta > 0 ? "+\(delta)" : "\(delta)"
    }

    private var underPar: Bool {
        guard let score = stats.score else { return false }
        return score - hole.par < 0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("HOLE SUMMARY")
                    .font(BrutalistType.mono(.semibold, size: 9))
                    .kerning(1.2)
                Spacer()
                Text(done ? "SIGNED" : "IN PROGRESS")
                    .font(BrutalistType.mono(.medium, size: 8.5))
                    .kerning(0.8)
                    .foregroundStyle(done ? BrutalistColor.acc : BrutalistColor.muted)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(BrutalistColor.hair).frame(height: 1) }

            HStack(spacing: 0) {
                scoreBlock
                statCell(label: "FIR", value: hitText(stats.fir), accent: stats.fir == .hit, dim: isDim(stats.fir))
                statCell(label: "GIR", value: hitText(stats.gir), accent: stats.gir == .hit, dim: isDim(stats.gir))
                statCell(label: "PUTTS", value: "\(stats.putts)", accent: false, dim: stats.putts == 0)
                statCell(label: "PEN", value: "\(stats.pen)", accent: false, dim: stats.pen == 0)
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.fg, lineWidth: 1.6))
    }

    private var scoreBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("SCORE · TO PAR")
                .font(BrutalistType.mono(.medium, size: 8))
                .kerning(1.4)
                .foregroundStyle(BrutalistColor.muted)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(stats.score.map { "\($0)" } ?? "–")
                    .font(BrutalistType.heroSecondary)
                    .kerning(-1.6)
                    .monospacedDigit()
                    .foregroundStyle(stats.score == nil ? BrutalistColor.dim : BrutalistColor.fg)
                Text(toParText)
                    .font(BrutalistType.mono(.semibold, size: 11))
                    .foregroundStyle(underPar ? BrutalistColor.acc : BrutalistColor.fg)
            }
            Text(stats.score.map { ScoreLabel.text(strokes: $0, par: hole.par) } ?? "—")
                .font(BrutalistType.mono(.medium, size: 8.5))
                .kerning(0.8)
                .foregroundStyle(underPar ? BrutalistColor.acc : BrutalistColor.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 104, alignment: .leading)
    }

    private func statCell(label: String, value: String, accent: Bool, dim: Bool) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(BrutalistType.mono(.medium, size: 8))
                .kerning(1.4)
                .foregroundStyle(BrutalistColor.muted)
            Text(value)
                .font(BrutalistType.mono(.semibold, size: 16))
                .monospacedDigit()
                .foregroundStyle(dim ? BrutalistColor.dim : accent ? BrutalistColor.acc : BrutalistColor.fg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .overlay(alignment: .leading) { Rectangle().fill(BrutalistColor.hair).frame(width: 1) }
    }

    private func hitText(_ state: HitState) -> String {
        switch state {
        case .hit: "✓"
        case .miss: "✕"
        case .unknown: "—"
        case .notApplicable: "N/A"
        }
    }

    /// Cells with no decisive value yet (unknown / N/A) render dim.
    private func isDim(_ state: HitState) -> Bool {
        state == .unknown || state == .notApplicable
    }
}
