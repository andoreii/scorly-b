import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Bottom-sheet scorecard. Header (course name + running total),
/// front-9 / back-9 grids with hole numbers, pars, and Pip notation
/// per logged hole. Tapping a cell jumps Play to that hole.
struct ScorecardSheetView: View {
    @Bindable var state: RoundPlayState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                grabHandle
                header
                summary
                HBar(vMargin: BrutalistSpacing.s)
                rows
                legend
            }
            .padding(.horizontal, 18)
            .padding(.top, BrutalistSpacing.s)
            .padding(.bottom, BrutalistSpacing.xxl)
        }
        .background(BrutalistColor.bg)
        .presentationDetents([.fraction(0.8)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Header

    private var grabHandle: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(BrutalistColor.fg)
                .frame(width: 44, height: 3)
            Spacer()
        }
        .padding(.bottom, BrutalistSpacing.s)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCORECARD")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(state.course.name)
                    .font(BrutalistType.sheetTitle)
                    .kerning(-0.6)
            }
            Spacer()
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Text("CLOSE ✕")
                    .font(BrutalistType.monoCaption)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
            }
            .buttonStyle(.plain)
        }
    }

    private var summary: some View {
        Text(summaryText)
            .font(BrutalistType.monoCaption)
            .kerning(0.6)
            .foregroundStyle(BrutalistColor.muted)
            .padding(.top, BrutalistSpacing.xs)
    }

    private var summaryText: String {
        let strokes = state.totalStrokes
        let par = state.playedPar
        guard par > 0 else { return "No strokes logged yet." }
        let diff = strokes - par
        let signed = diff >= 0 ? "+\(diff)" : "\(diff)"
        return "\(strokes) STROKES · \(signed) VS PAR \(par)"
    }

    // MARK: - Rows

    private var rows: some View {
        let count = state.holes.count
        let groups: [(label: String, range: Range<Int>)] = {
            if count == 18 {
                return [
                    (label: "FRONT NINE", range: 0..<9),
                    (label: "BACK NINE", range: 9..<18),
                ]
            }
            return [(label: "HOLES", range: 0..<count)]
        }()
        return VStack(alignment: .leading, spacing: BrutalistSpacing.m) {
            ForEach(groups.indices, id: \.self) { index in
                groupBlock(label: groups[index].label, range: groups[index].range)
            }
        }
    }

    private func groupBlock(label: String, range: Range<Int>) -> some View {
        let strokes = range.reduce(0) { $0 + (state.entries[$1].strokes ?? 0) }
        let par = range.reduce(0) { acc, i in
            state.entries[i].strokes != nil ? acc + state.holes[i].par : acc
        }
        let runningText: String = {
            guard strokes > 0 else { return "—" }
            let diff = strokes - par
            let signed = diff >= 0 ? "+\(diff)" : "\(diff)"
            return "\(strokes) · \(signed)"
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(BrutalistType.monoLabel)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                Text(runningText)
                    .font(BrutalistType.monoLabel)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
            }
            scorecardGrid(range: range)
        }
    }

    private func scorecardGrid(range: Range<Int>) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: range.count)
        return VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(range, id: \.self) { index in
                    headerCell(index: index, lastColumn: index == range.upperBound - 1)
                }
            }
            .overlay(Rectangle().fill(BrutalistColor.hair).frame(height: 1), alignment: .bottom)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(range, id: \.self) { index in
                    scoreCell(index: index, lastColumn: index == range.upperBound - 1)
                }
            }
        }
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    private func headerCell(index: Int, lastColumn: Bool) -> some View {
        let hole = state.holes[index]
        return VStack(spacing: 2) {
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
            if !lastColumn {
                Rectangle().fill(BrutalistColor.hair).frame(width: 1)
            }
        }
    }

    private func scoreCell(index: Int, lastColumn: Bool) -> some View {
        let hole = state.holes[index]
        let entry = state.entries[index]
        let here = index == state.holeIdx
        return Button {
            Haptics.light()
            state.jump(to: index)
            dismiss()
        } label: {
            Pip(
                strokes: entry.strokes,
                par: hole.par,
                size: 22,
                weight: 1.2,
                color: here ? BrutalistColor.bg : BrutalistColor.fg,
                mutedColor: here ? BrutalistColor.invMuted : BrutalistColor.dim
            )
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(here ? BrutalistColor.fg : Color.clear)
            .overlay(alignment: .trailing) {
                if !lastColumn {
                    Rectangle().fill(BrutalistColor.hair).frame(width: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 14) {
            Legend(label: "BIRDIE+") { Pip(strokes: 3, par: 4, size: 14, weight: 1) }
            Legend(label: "PAR") { Pip(strokes: 4, par: 4, size: 14, weight: 1) }
            Legend(label: "BOGEY+") { Pip(strokes: 5, par: 4, size: 14, weight: 1) }
            Spacer(minLength: 0)
        }
        .padding(.top, BrutalistSpacing.m)
    }
}
