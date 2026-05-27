import SwiftUI

public struct PuttingSummaryCard: View {
    private let totalPutts: Int
    private let averagePuttsPerHole: Double?
    private let stats: [PuttDistanceBucket: PuttMakeValues]

    public init(
        totalPutts: Int,
        averagePuttsPerHole: Double?,
        stats: [PuttDistanceBucket: PuttMakeValues]
    ) {
        self.totalPutts = totalPutts
        self.averagePuttsPerHole = averagePuttsPerHole
        self.stats = stats
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReviewCardHeader(meta: "PUTTING", title: "Touch", trailing: nil)
            HBar(vMargin: 0)
            HStack(spacing: 0) {
                summaryCell(label: "TOTAL PUTTS", value: "\(totalPutts)")
                summaryCell(
                    label: "AVG PUTTS / HOLE",
                    value: averagePuttsPerHole.map { String(format: "%.1f", $0) } ?? "-",
                    leadingBorder: true
                )
            }
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            HBar(vMargin: 0)
            Text("MAKE % BY DISTANCE · FEET")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            PuttMakeRateRows(stats: stats)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func summaryCell(label: String, value: String, leadingBorder: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(BrutalistType.sans(.bold, size: 32))
                .kerning(-1)
                .monospacedDigit()
                .foregroundStyle(BrutalistColor.fg)
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .overlay(alignment: .leading) {
            if leadingBorder {
                Rectangle().fill(BrutalistColor.rule).frame(width: 1)
            }
        }
    }
}

public struct PuttMakeRateCard: View {
    private let stats: [PuttDistanceBucket: PuttMakeValues]

    public init(stats: [PuttDistanceBucket: PuttMakeValues]) {
        self.stats = stats
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReviewCardHeader(meta: "PUTTING", title: "Make rate", trailing: "FEET")
            HBar(vMargin: 0)
            PuttMakeRateRows(stats: stats)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }
}

private struct PuttMakeRateRows: View {
    let stats: [PuttDistanceBucket: PuttMakeValues]

    var body: some View {
        ForEach(PuttDistanceBucket.allCases) { bucket in
            let stat = stats[bucket] ?? PuttMakeValues()
            HStack(spacing: 12) {
                Text(bucket.rawValue)
                    .font(BrutalistType.monoCaption)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .leading)
                GeometryReader { proxy in
                    let fillWidth = proxy.size.width * CGFloat(stat.rate ?? 0)
                    ZStack(alignment: .leading) {
                        Rectangle().fill(BrutalistColor.panel)
                        Rectangle().fill(BrutalistColor.sgPosFill).frame(width: fillWidth)
                        Rectangle()
                            .fill(BrutalistColor.sgPos)
                            .frame(width: 1)
                            .offset(x: max(0, fillWidth - 1))
                            .opacity(stat.rate == nil ? 0 : 1)
                    }
                    .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                }
                .frame(height: 16)
                Text(percentLabel(stat.rate))
                    .font(BrutalistType.mono(.semibold, size: 12))
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                    .frame(width: 38, alignment: .trailing)
                Text("(\(stat.attempted))")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.4)
                    .foregroundStyle(BrutalistColor.dim)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.vertical, 6)
        }
    }

    private func percentLabel(_ rate: Double?) -> String {
        guard let rate else { return "-" }
        return "\(Int((rate * 100).rounded()))%"
    }
}
