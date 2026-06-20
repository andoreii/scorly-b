import SwiftUI

public struct RoundScoringDistributionCard: View {
    private let counts: [ScoringOutcome: Int]
    private let total: Int
    private let scoreToPar: Int

    public init(counts: [ScoringOutcome: Int], total: Int, scoreToPar: Int) {
        self.counts = counts
        self.total = total
        self.scoreToPar = scoreToPar
    }

    public var body: some View {
        ReviewDisclosureCard(
            meta: "SCORING · SINGLE ROUND",
            title: "Scoring distribution",
            metric: "\(parOrBetterPercent)% PAR+"
        ) {
            VStack(alignment: .leading, spacing: 0) {
                heroes
                spectrumSection
                    .padding(.top, 20)
            }
        }
    }

    private var heroes: some View {
        HStack(alignment: .center, spacing: 0) {
            heroStat(value: "\(parOrBetterPercent)", unit: "%", label: "PAR OR BETTER")
            Rectangle()
                .fill(BrutalistColor.hair)
                .frame(width: 1, height: 56)
            heroStat(value: formattedSigned(scoreToPar), unit: "/rd", label: "SCORE TO PAR")
        }
    }

    private func heroStat(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(BrutalistType.mono(.semibold, size: 42))
                    .kerning(-1.8)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(BrutalistType.mono(.semibold, size: 16))
                    .foregroundStyle(BrutalistColor.muted)
            }
            Text(label)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var spectrumSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("THE MIX · SHARE OF HOLES")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                Text("\(total) HOLES SCORED")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.muted)
                    .monospacedDigit()
            }
            spectrumBar
            spectrumLegend
                .padding(.top, 10)
        }
    }

    private var spectrumBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 0) {
                spectrumSegment(color: BrutalistColor.sgPos, outcome: .birdiePlus, light: false)
                spectrumSegment(color: BrutalistColor.parInk, outcome: .par, light: false)
                spectrumSegment(color: BrutalistColor.stone, outcome: .bogey, light: true)
                spectrumSegment(color: BrutalistColor.sgNeg, outcome: .doublePlus, light: false)
            }
            .frame(width: width, height: 38)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            Rectangle()
                .fill(BrutalistColor.fg)
                .frame(width: 2, height: 48)
                .offset(x: width * parOrBetterFraction - 1, y: -5)
            Text("↑ \(parOrBetterPercent)% PAR OR BETTER")
                .font(BrutalistType.mono(.semibold, size: 8))
                .kerning(0.5)
                .foregroundStyle(BrutalistColor.fg)
                .fixedSize()
                .offset(
                    x: max(0, min(width - 110, width * parOrBetterFraction - 55)),
                    y: 44
                )
        }
        .frame(height: 60)
    }

    private func spectrumSegment(color: Color, outcome: ScoringOutcome, light: Bool) -> some View {
        let fraction = fraction(for: outcome)
        return ZStack {
            color
            if fraction > 0.04 {
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(BrutalistType.mono(.semibold, size: 12))
                    .foregroundStyle(light ? BrutalistColor.fg : BrutalistColor.bg)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var spectrumLegend: some View {
        HStack(spacing: 8) {
            legendCell(label: "BIRDIE+", outcome: .birdiePlus, color: BrutalistColor.sgPos)
            legendCell(label: "PAR", outcome: .par, color: BrutalistColor.parInk)
            legendCell(label: "BOGEY", outcome: .bogey, color: BrutalistColor.stone)
            legendCell(label: "DBL+", outcome: .doublePlus, color: BrutalistColor.sgNeg)
        }
    }

    private func legendCell(label: String, outcome: ScoringOutcome, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 0.5))
                Text(label)
                    .font(BrutalistType.monoMicro)
                    .kerning(0.4)
                    .foregroundStyle(BrutalistColor.muted)
            }
            Text("\(counts[outcome] ?? 0) HOLES")
                .font(BrutalistType.monoMicro)
                .kerning(0.3)
                .foregroundStyle(BrutalistColor.dim)
                .monospacedDigit()
                .padding(.leading, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var parOrBetterPercent: Int {
        Int((parOrBetterFraction * 100).rounded())
    }

    private var parOrBetterFraction: Double {
        fraction(for: .birdiePlus) + fraction(for: .par)
    }

    private func fraction(for outcome: ScoringOutcome) -> Double {
        total > 0 ? Double(counts[outcome] ?? 0) / Double(total) : 0
    }

    private func formattedSigned(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}
