import ScorlyDesignSystem
import SwiftUI

/// Pre-Sign-&-File pass that lets the user backfill missing chip-phase data.
/// Reuses `ARGEditorSection`'s primitives (LieKeypad, DistanceWheel, etc.) so this
/// matches in-round entry; edits mutate `RoundPlayState` directly.
struct SGRefinementSheet: View {
    @Bindable var state: RoundPlayState

    @Environment(\.dismiss)
    private var dismiss
    @State private var expandedHole: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    grabHandle
                    header
                    HBar(vMargin: BrutalistSpacing.m)
                    if eligibleIndices.isEmpty {
                        emptyState
                    } else {
                        ForEach(eligibleIndices, id: \.self) { index in
                            holeRow(index: index)
                            HBar(vMargin: BrutalistSpacing.m)
                        }
                    }
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
        .presentationDetents([.fraction(0.8)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Eligibility

    /// Holes with a chip phase — includes fully-recorded ones for context, not just estimated rows.
    private var eligibleIndices: [Int] {
        state.holes.indices.filter { state.inferredARGCount(at: $0) > 0 }
    }

    private func isEstimated(index: Int) -> Bool {
        let inferred = state.inferredARGCount(at: index)
        let recorded = state.recordedARGCount(at: index)
        return recorded < inferred
    }

    // MARK: - Chrome

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
                Text("REFINE SG")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(headerTitle)
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

    private var headerTitle: String {
        let estimated = eligibleIndices.filter(isEstimated).count
        if estimated == 0 { return "All holes recorded" }
        return "\(estimated) hole\(estimated == 1 ? "" : "s") missing detail"
    }

    private var emptyState: some View {
        Text("No around-the-green shots in this round.")
            .font(BrutalistType.body)
            .foregroundStyle(BrutalistColor.muted)
            .padding(.top, BrutalistSpacing.m)
    }

    // MARK: - Per-hole row

    @ViewBuilder
    private func holeRow(index: Int) -> some View {
        let expanded = expandedHole == index
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(rowLabel(index: index))
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                Spacer()
                Text(rowStatus(index: index))
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(isEstimated(index: index) ? BrutalistColor.fg : BrutalistColor.muted)
                Text(expanded ? "▴" : "▾")
                    .font(BrutalistType.monoCaption)
                    .padding(.leading, 6)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .brutalistTap {
                Haptics.soft()
                withAnimation { expandedHole = expanded ? nil : index }
            }
            if expanded {
                editorBody(index: index)
                    .padding(.bottom, BrutalistSpacing.s)
            }
        }
    }

    private func rowLabel(index: Int) -> String {
        let hole = state.holes[index]
        return "HOLE \(String(format: "%02d", hole.number)) · PAR \(hole.par)"
    }

    private func rowStatus(index: Int) -> String {
        let inferred = state.inferredARGCount(at: index)
        let recorded = state.recordedARGCount(at: index)
        if recorded >= inferred { return "RECORDED" }
        return "\(recorded) / \(inferred) RECORDED"
    }

    @ViewBuilder
    private func editorBody(index: Int) -> some View {
        let count = state.inferredARGCount(at: index)
        VStack(alignment: .leading, spacing: BrutalistSpacing.m) {
            ForEach(0..<count, id: \.self) { slot in
                VStack(alignment: .leading, spacing: 6) {
                    SubLabel("Shot \(slot + 1) of \(count)")
                    LieKeypad(
                        value: lieBinding(hole: index, slot: slot),
                        modifier: modifierBinding(hole: index, slot: slot),
                        target: "Green"
                    )
                    if ARGEditorSection.showsTransitionDistance(after: slot, count: count) {
                        VStack(alignment: .leading, spacing: 6) {
                            SubLabel("Landed at (from pin)")
                            DistanceWheel(
                                value: transitionDistanceBinding(hole: index, after: slot),
                                range: 1...150,
                                step: 1,
                                majorEvery: 10,
                                unit: "YDS"
                            )
                        }
                        .padding(.top, 10)
                    }
                }
            }
        }
    }

    // MARK: - Bindings

    private func lieBinding(hole: Int, slot: Int) -> Binding<String?> {
        Binding(
            get: { argEntry(hole: hole, slot: slot)?.lie },
            set: { newValue in
                mutateARGEntry(hole: hole, slot: slot) { $0.lie = newValue }
            }
        )
    }

    private func modifierBinding(hole: Int, slot: Int) -> Binding<String?> {
        Binding(
            get: { argEntry(hole: hole, slot: slot)?.lieModifier },
            set: { newValue in
                mutateARGEntry(hole: hole, slot: slot) { $0.lieModifier = newValue }
            }
        )
    }

    private func transitionDistanceBinding(hole: Int, after slot: Int) -> Binding<Int?> {
        Binding(
            get: { state.argStartDistance(slot: slot + 1, at: hole) },
            set: { state.setARGTransitionDistance($0, after: slot, at: hole) }
        )
    }

    private func argEntry(hole: Int, slot: Int) -> ARGShotEntry? {
        guard state.entries.indices.contains(hole) else { return nil }
        let entries = state.entries[hole].argShots ?? []
        return entries.indices.contains(slot) ? entries[slot] : nil
    }

    private func mutateARGEntry(hole: Int, slot: Int, _ apply: (inout ARGShotEntry) -> Void) {
        guard state.entries.indices.contains(hole) else { return }
        var current = state.entries[hole].argShots ?? []
        while current.count <= slot {
            current.append(ARGShotEntry())
        }
        apply(&current[slot])
        let inferred = state.inferredARGCount(at: hole)
        if current.count > inferred {
            current = Array(current.prefix(inferred))
        }
        state.entries[hole].argShots = current.isEmpty ? nil : current
    }

    // MARK: - Done

    private var doneButton: some View {
        BrutalistButton(
            kind: .fg,
            action: dismissSheet,
            padding: EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        ) {
            Text("DONE")
                .font(BrutalistType.sans(.bold, size: 15))
                .kerning(0.4)
        }
    }

    private func dismissSheet() {
        dismiss()
    }
}
