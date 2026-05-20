import ScorlyDesignSystem
import SwiftUI

/// Bottom sheet that hosts the putting editor (putt count + per-putt
/// distances). Same chrome as `ShotSheetView` / `PenaltySheetView`.
struct PuttingSheetView: View {
    @Bindable var state: RoundPlayState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    grabHandle
                    header
                    HBar(vMargin: BrutalistSpacing.m)
                    PuttingEditor(
                        putts: puttsBinding,
                        distances: distancesBinding
                    )
                }
                .padding(.horizontal, BrutalistSpacing.pageHorizontal)
                .padding(.top, BrutalistSpacing.s)
                .padding(.bottom, BrutalistSpacing.m)
            }
            doneButton
                .padding(.horizontal, BrutalistSpacing.pageHorizontal)
                .padding(.top, BrutalistSpacing.m)
                .padding(.bottom, BrutalistSpacing.m)
                .background(BrutalistColor.bg)
        }
        .background(BrutalistColor.bg)
        .foregroundStyle(BrutalistColor.fg)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

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
                Text("PUTTING")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text("Hole \(state.currentHole.number)")
                    .font(BrutalistType.sheetTitle)
                    .kerning(-0.6)
            }
            Spacer()
            Text("CLOSE ✕")
                .font(BrutalistType.monoCaption)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
                .brutalistTap { dismiss() }
        }
    }

    private var doneButton: some View {
        BrutalistButton(
            kind: .fg,
            action: { dismiss() },
            padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        ) {
            Text("DONE")
                .font(BrutalistType.sans(.bold, size: 15))
                .kerning(0.4)
        }
    }

    private var puttsBinding: Binding<Int> {
        Binding(
            get: { state.currentEntry.putts },
            set: { newValue in
                var entry = state.entries[state.holeIdx]
                entry.putts = newValue
                if entry.puttDistances.count > newValue {
                    entry.puttDistances = Array(entry.puttDistances.prefix(newValue))
                }
                state.entries[state.holeIdx] = entry
            }
        )
    }

    private var distancesBinding: Binding<[Int?]> {
        Binding(
            get: { state.currentEntry.puttDistances },
            set: { state.entries[state.holeIdx].puttDistances = $0 }
        )
    }
}
