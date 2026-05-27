import ScorlyDesignSystem
import SwiftUI

/// Fixed top header on the Trend page. Three stats — average score,
/// best vs par, worst vs par — sit above a chronological raw-score
/// line graph. Pinned outside the carousel rotation so the user always
/// has a reference point while swiping.
struct ScoreSummaryHeader: View {
    let avgScore: Double?
    let bestVsPar: Int?
    let worstVsPar: Int?
    /// Chronological points (oldest → newest), each carrying its
    /// date so the line graph can render month-zone labels along
    /// the x-axis without a second pass over the timeline.
    let scorePoints: [ScoreLinePoint]

    private let chartHeight: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                BrutalistColor.panel
                CornerMarks(size: 6, inset: 4)
                HStack(spacing: 0) {
                    BigStat(
                        label: "Avg Score",
                        value: avgScore.map { String(format: "%.1f", $0) } ?? "—"
                    )
                    BigStat(
                        label: "Best v Par",
                        value: bestVsPar.map(Self.signed) ?? "—",
                        drawBorder: true
                    )
                    BigStat(
                        label: "Worst v Par",
                        value: worstVsPar.map(Self.signed) ?? "—",
                        drawBorder: true
                    )
                }
            }
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SCORE BY ROUND")
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.fg)
                    Spacer()
                    Text("N=\(scorePoints.count)")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                        .monospacedDigit()
                }
                ScoreVsParLine(points: scorePoints)
                    .frame(height: chartHeight)
            }
            .padding(14)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
    }

    private static func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
