import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Bottom-sheet penalty + manual overrides editor. Holds the penalty
/// stepper plus the conditional Up&Down / Sand Save tiles that used to
/// live inline in `PlayView` — moved out so the default round-play
/// screen fits without scrolling.
struct PenaltySheetView: View {
    @Bindable var state: RoundPlayState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    grabHandle
                    header
                    HBar(vMargin: BrutalistSpacing.m)
                    penaltyStepper
                    manualOverrides
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
        .presentationDetents([.fraction(0.55)])
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
                Text("PENALTY · MANUAL")
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

    // MARK: - Penalty stepper

    private var penaltyStepper: some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Penalty Strokes")
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UNPLAYABLES · LATERAL DROPS · ETC.")
                        .font(BrutalistType.mono(.medium, size: 9))
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                    Text("\(state.currentEntry.penaltyStrokes)")
                        .font(BrutalistType.mediumValue)
                        .kerning(-0.8)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                HStack(spacing: 6) {
                    SmallStep("−") {
                        withAnimation(Motion.snap) {
                            state.entries[state.holeIdx].penaltyStrokes = max(0, state.currentEntry.penaltyStrokes - 1)
                        }
                    }
                    SmallStep("+") {
                        withAnimation(Motion.snap) {
                            state.entries[state.holeIdx].penaltyStrokes = min(9, state.currentEntry.penaltyStrokes + 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
        .padding(.top, BrutalistSpacing.m)
    }

    // MARK: - Manual overrides

    @ViewBuilder
    private var manualOverrides: some View {
        let stat = state.derivedStat(for: state.holeIdx)
        let showUpDown = !stat.greenInRegulation
        let showSandSave = stat.bunkerCount > 0 && !stat.greenInRegulation
        if showUpDown || showSandSave {
            VStack(alignment: .leading, spacing: 6) {
                SubLabel("Manual Overrides")
                let columns = (showUpDown && showSandSave) ? 2 : 1
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                    spacing: 10
                ) {
                    if showUpDown {
                        OverrideTile(
                            label: "Up & Down",
                            auto: stat.upAndDown,
                            value: Binding(
                                get: { state.currentEntry.upAndDownOverride },
                                set: { state.entries[state.holeIdx].upAndDownOverride = $0 }
                            )
                        )
                    }
                    if showSandSave {
                        OverrideTile(
                            label: "Sand Save",
                            auto: stat.sandSave,
                            value: Binding(
                                get: { state.currentEntry.sandSaveOverride },
                                set: { state.entries[state.holeIdx].sandSaveOverride = $0 }
                            )
                        )
                    }
                }
            }
            .padding(.top, BrutalistSpacing.l)
        }
    }

    // MARK: - Done

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
}
