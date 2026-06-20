import SwiftUI

public struct PuttingSummaryCard: View {
    private let totalPutts: Int
    private let averagePuttsPerHole: Double?
    private let profile: [PuttingAveragePoint]
    private let distribution: PuttDistributionValues

    public init(
        totalPutts: Int,
        averagePuttsPerHole: Double?,
        profile: [PuttingAveragePoint],
        distribution: PuttDistributionValues
    ) {
        self.totalPutts = totalPutts
        self.averagePuttsPerHole = averagePuttsPerHole
        self.profile = profile
        self.distribution = distribution
    }

    public var body: some View {
        ReviewDisclosureCard(
            meta: "PUTTING · SINGLE ROUND",
            title: "Putting",
            metric: metricLabel
        ) {
            VStack(alignment: .leading, spacing: 0) {
                heroRow
                SingleRoundPuttDistributionBar(distribution: distribution)
                    .padding(.top, 28)
                insetDivider
                    .padding(.vertical, 28)
                HStack {
                    Text("AVG PUTTS / HOLE")
                        .font(BrutalistType.mono(.semibold, size: 10))
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.fg)
                    Spacer()
                    Text("RUNNING AVG · \(profile.count) HOLES")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .monospacedDigit()
                        .foregroundStyle(BrutalistColor.muted)
                }
                PuttingProfileChart(points: profile, average: averagePuttsPerHole)
                    .frame(height: 180)
                    .padding(.top, 4)
                HStack(spacing: 6) {
                    Circle()
                        .fill(BrutalistColor.sgNeg)
                        .frame(width: 9, height: 9)
                    Text("THREE-PUTT HOLE · \(distribution.threePuttPlus)")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.5)
                        .monospacedDigit()
                        .foregroundStyle(BrutalistColor.muted)
                }
                .padding(.top, 12)
            }
        }
    }

    private var metricLabel: String {
        guard let averagePuttsPerHole else { return "- / HOLE" }
        return "\(String(format: "%.2f", averagePuttsPerHole)) / HOLE"
    }

    private var heroRow: some View {
        HStack(alignment: .center, spacing: 0) {
            puttingHero(value: Double(totalPutts), fractionDigits: 0, unit: "/rd", label: "TOTAL PUTTS")
            Rectangle()
                .fill(BrutalistColor.hair)
                .frame(width: 1, height: 56)
            puttingHero(value: averagePuttsPerHole, fractionDigits: 2, unit: "/h", label: "AVG PER HOLE")
        }
    }

    private func puttingHero(value: Double?, fractionDigits: Int, unit: String, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(format(value, fractionDigits: fractionDigits))
                    .font(BrutalistType.mono(.semibold, size: 34))
                    .kerning(-1.2)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                Text(unit)
                    .font(BrutalistType.mono(.semibold, size: 13))
                    .foregroundStyle(BrutalistColor.muted)
            }
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var insetDivider: some View {
        Rectangle()
            .fill(BrutalistColor.hair)
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    private func format(_ value: Double?, fractionDigits: Int) -> String {
        guard let value else { return "—" }
        return String(format: "%.\(fractionDigits)f", value)
    }
}

private struct SingleRoundPuttDistributionBar: View {
    let distribution: PuttDistributionValues

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("PUTT DISTRIBUTION · SHARE OF HOLES")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    segment(color: BrutalistColor.sgPos, count: distribution.onePutt)
                    segment(color: BrutalistColor.dim, count: distribution.twoPutt)
                    segment(color: BrutalistColor.sgNeg, count: distribution.threePuttPlus)
                }
                .frame(width: proxy.size.width, height: 34)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            }
            .frame(height: 34)
            HStack(spacing: 0) {
                legendChip(label: "ONE-PUTT", color: BrutalistColor.sgPos)
                    .frame(maxWidth: .infinity, alignment: .leading)
                legendChip(label: "TWO-PUTT", color: BrutalistColor.dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                legendChip(label: "THREE-PUTT+", color: BrutalistColor.sgNeg)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.top, 4)
        }
    }

    private func segment(color: Color, count: Int) -> some View {
        let fraction = distribution.share(count)
        return ZStack {
            color
            if fraction > 0.06 {
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(BrutalistType.mono(.semibold, size: 12))
                    .foregroundStyle(BrutalistColor.bg)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendChip(label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 0.5))
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.5)
                .foregroundStyle(BrutalistColor.muted)
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
