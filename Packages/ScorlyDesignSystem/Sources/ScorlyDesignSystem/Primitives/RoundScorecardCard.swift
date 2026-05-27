import SwiftUI

public struct RoundScorecardCard: View {
    private let groups: [ScorecardGroupValues]

    public init(groups: [ScorecardGroupValues]) {
        self.groups = groups
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.m) {
            ReviewCardHeader(meta: "SCORECARD", title: "Filed card", trailing: nil)
            ForEach(groups) { group in
                scorecardGroup(group)
            }
            HStack(spacing: 14) {
                Legend(label: "BIRDIE+") { Pip(strokes: 3, par: 4, size: 14, weight: 1) }
                Legend(label: "PAR") { Pip(strokes: 4, par: 4, size: 14, weight: 1) }
                Legend(label: "BOGEY+") { Pip(strokes: 5, par: 4, size: 14, weight: 1) }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func scorecardGroup(_ group: ScorecardGroupValues) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(group.label)
                    .font(BrutalistType.monoLabel)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                Text(groupSummary(group))
                    .font(BrutalistType.monoLabel)
                    .kerning(0.8)
                    .monospacedDigit()
                    .foregroundStyle(BrutalistColor.muted)
            }
            scorecardGrid(group.holes)
        }
    }

    private func scorecardGrid(_ holes: [ScorecardHoleValues]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: max(holes.count, 1))
        return VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(holes.enumerated()), id: \.element.id) { index, hole in
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", hole.number))
                            .font(BrutalistType.mono(.medium, size: 9))
                            .kerning(0.4)
                            .foregroundStyle(BrutalistColor.muted)
                        Text("P\(hole.par)")
                            .font(BrutalistType.mono(.medium, size: 9))
                            .kerning(0.4)
                            .foregroundStyle(BrutalistColor.dim)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        if index < holes.count - 1 {
                            Rectangle().fill(BrutalistColor.hair).frame(width: 1)
                        }
                    }
                }
            }
            .overlay(Rectangle().fill(BrutalistColor.hair).frame(height: 1), alignment: .bottom)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(holes.enumerated()), id: \.element.id) { index, hole in
                    Pip(strokes: hole.strokes, par: hole.par, size: 22, weight: 1.2)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) {
                            if index < holes.count - 1 {
                                Rectangle().fill(BrutalistColor.hair).frame(width: 1)
                            }
                        }
                }
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func groupSummary(_ group: ScorecardGroupValues) -> String {
        guard group.strokes > 0 else { return "-" }
        let difference = group.strokes - group.playedPar
        return "\(group.strokes) · \(difference >= 0 ? "+" : "")\(difference)"
    }
}
