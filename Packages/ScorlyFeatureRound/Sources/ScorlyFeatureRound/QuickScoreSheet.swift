import ScorlyDesignSystem
import ScorlyDomain
import SwiftUI

/// Score-only fallback. The Thread is the primary way to log a hole, but
/// a golfer who didn't track every shot can still punch in a total score
/// and putt count here — preserving the old strokes-stepper behaviour and
/// keeping partial rounds intact. Writes `strokes` / `putts` straight onto
/// the `HoleEntry`, exactly as the old stepper did.
struct QuickScoreSheet: View {
    @Bindable var state: RoundPlayState
    let onClose: () -> Void

    private var hole: Hole {
        state.currentHole
    }

    private var idx: Int {
        state.holeIdx
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.l) {
            HStack {
                Text("QUICK SCORE · HOLE \(String(format: "%02d", hole.number))")
                    .font(BrutalistType.mono(.semibold, size: 10))
                    .kerning(1.2)
                Spacer()
                Text("✕")
                    .font(BrutalistType.mono(.medium, size: 15))
                    .foregroundStyle(BrutalistColor.muted)
                    .brutalistTap(action: onClose)
            }

            Text("No shot detail — just the numbers. Tracking shot-by-shot? Tap a node on the Thread instead.")
                .font(BrutalistType.mono(.medium, size: 10))
                .foregroundStyle(BrutalistColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            field("STROKES") {
                BrutalistStepper(value: strokesBinding, range: 1...15)
            } trailing: {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(ScoreLabel.text(strokes: strokesBinding.wrappedValue, par: hole.par))
                        .font(BrutalistType.mono(.semibold, size: 11))
                        .kerning(1.2)
                    Pip(strokes: strokesBinding.wrappedValue, par: hole.par, size: 28, weight: 1.4)
                }
            }

            field("PUTTS") {
                BrutalistStepper(value: puttsBinding, range: 0...10)
            } trailing: { EmptyView() }

            Spacer(minLength: 0)
        }
        .padding(BrutalistSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(BrutalistColor.bg.ignoresSafeArea())
        .foregroundStyle(BrutalistColor.fg)
        .presentationDetents([.medium])
    }

    private func field(
        _ label: String,
        @ViewBuilder content: () -> some View,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: BrutalistSpacing.s) {
            Text(label)
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.muted)
            HStack {
                content()
                Spacer()
                trailing()
            }
        }
    }

    private var strokesBinding: Binding<Int> {
        Binding(
            get: { state.entries[idx].strokes ?? hole.par },
            set: { state.entries[idx].strokes = $0 }
        )
    }

    private var puttsBinding: Binding<Int> {
        Binding(
            get: { state.entries[idx].putts },
            set: { state.entries[idx].putts = $0 }
        )
    }
}
