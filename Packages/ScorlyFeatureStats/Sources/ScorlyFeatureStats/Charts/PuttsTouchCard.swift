import ScorlyDesignSystem
import SwiftUI

/// Touch carousel slide 1. Avg putts per round as a hero number, two
/// mini-stats for 1-putt% and 3-putt%, plus a tall putts/round chart
/// and a tall 3-putts/round chart. Both charts use `ChartedLine`
/// so the trends read like real charts with their own AVG labels.
struct PuttsTouchCard: View {
    let avgPuttsPerRound: Double?
    let onePuttRate: Double?
    let threePuttRate: Double?
    let puttsSeries: [Double]
    let threePuttSeries: [Double]

    var body: some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.bg
            CornerMarks(size: 6, inset: 4)
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(meta: "PUTTS", title: "Putting", trailing: nil)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(avgString(avgPuttsPerRound))
                            .font(BrutalistType.sans(.bold, size: 44))
                            .kerning(-1.6)
                            .monospacedDigit()
                            .foregroundStyle(BrutalistColor.fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("AVG PUTTS / ROUND")
                            .font(BrutalistType.monoLabel)
                            .kerning(1.0)
                            .foregroundStyle(BrutalistColor.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        miniStat(label: "1-PUTT", rate: onePuttRate)
                        miniStat(label: "3-PUTT", rate: threePuttRate)
                    }
                }
                Rectangle().fill(BrutalistColor.hair).frame(height: 1)
                section(label: "PUTTS / ROUND") {
                    ChartedLine(series: puttsSeries, format: .decimal, height: 96)
                }
                Rectangle().fill(BrutalistColor.hair).frame(height: 1)
                section(label: "3-PUTTS / ROUND") {
                    ChartedLine(series: threePuttSeries, format: .decimal, height: 96)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func section<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.dim)
            content()
        }
    }

    private func miniStat(label: String, rate: Double?) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(percentLabel(rate))
                .font(BrutalistType.sans(.bold, size: 18))
                .kerning(-0.4)
                .monospacedDigit()
                .foregroundStyle(BrutalistColor.fg)
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
        }
    }

    private func avgString(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    private func percentLabel(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return "\(Int((rate * 100).rounded()))%"
    }
}
