import SwiftUI

public enum AccuracyRoseKind: Sendable {
    case fairway
    case green

    var title: String {
        switch self {
        case .fairway: "Fairways"
        case .green: "Greens"
        }
    }

    var meta: String {
        switch self {
        case .fairway: "FAIRWAYS IN REG"
        case .green: "GREENS IN REG"
        }
    }

    var directions: [AccuracyRoseValues.Direction] {
        AccuracyRoseValues.Direction.allCases
    }

    var abbreviation: String {
        switch self {
        case .fairway: "FIR"
        case .green: "GIR"
        }
    }
}

public struct AccuracyRoseCard<Footer: View>: View {
    private let kind: AccuracyRoseKind
    private let values: AccuracyRoseValues
    private let footer: Footer?

    public init(
        kind: AccuracyRoseKind,
        values: AccuracyRoseValues,
        @ViewBuilder footer: () -> Footer
    ) {
        self.kind = kind
        self.values = values
        self.footer = footer()
    }

    public var body: some View {
        ReviewDisclosureCard(
            meta: "ACCURACY · SINGLE ROUND",
            title: kind.title,
            metric: metricLabel
        ) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("MISS PATTERN")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .foregroundStyle(BrutalistColor.muted)
                    Spacer()
                    Text("N=\(values.opportunities)")
                        .font(BrutalistType.monoMicro)
                        .kerning(0.8)
                        .monospacedDigit()
                        .foregroundStyle(BrutalistColor.muted)
                }
                AccuracyWindrose(values: values)
                    .frame(maxWidth: 256)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                hero
                    .padding(.top, 4)
                AccuracyRoseLegend()
                    .padding(.top, 12)
                if let footer {
                    Rectangle()
                        .fill(BrutalistColor.hair)
                        .frame(height: 1)
                        .padding(.vertical, 18)
                    footer
                }
            }
        }
    }

    private var metricLabel: String {
        guard let rate = values.hitRate else { return "- \(kind.abbreviation)" }
        return "\(Int((rate * 100).rounded()))% \(kind.abbreviation)"
    }

    private var hero: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(heroNumber)
                    .font(BrutalistType.mono(.semibold, size: 44))
                    .kerning(-1.8)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.fg)
                Text("%")
                    .font(BrutalistType.mono(.semibold, size: 18))
                    .foregroundStyle(BrutalistColor.muted)
            }
            Text(kind.hitLabel)
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroNumber: String {
        guard let rate = values.hitRate else { return "—" }
        return "\(Int((rate * 100).rounded()))"
    }
}

public extension AccuracyRoseCard where Footer == EmptyView {
    init(kind: AccuracyRoseKind, values: AccuracyRoseValues) {
        self.kind = kind
        self.values = values
        footer = nil
    }
}

private struct AccuracyRoseLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            legendItem("ROUGH", color: AccuracyHazardPalette.rough)
            legendItem("BUNKER", color: AccuracyHazardPalette.bunker)
            legendItem("OB", color: AccuracyHazardPalette.ob)
            Spacer(minLength: 0)
        }
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(width: 11, height: 11)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            Text(label)
                .font(BrutalistType.mono(.medium, size: 9))
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
        }
    }
}
