import ScorlyDesignSystem
import SwiftUI

/// Editor for around-the-green shots. Used by the live-round ARG
/// sheet and the sign-and-file refinement pass.
struct ARGEditorSection: View {
    @Bindable var state: RoundPlayState
    let holeIndex: Int

    var body: some View {
        let count = argCount
        if count > 0 {
            VStack(alignment: .leading, spacing: 0) {
                SubLabel(headerLabel(count: count))
                    .padding(.bottom, 2)
                ForEach(0..<count, id: \.self) { index in
                    slotEditor(index: index, count: count)
                    if index < count - 1 {
                        HBar(vMargin: BrutalistSpacing.l)
                    }
                }
            }
        }
    }

    private var argCount: Int {
        state.inferredARGCount(at: holeIndex)
    }

    private func headerLabel(count: Int) -> String {
        let suffix = count == 1 ? "1 shot" : "\(count) shots"
        return "Around the Green · \(suffix)"
    }

    private func slotEditor(index: Int, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SubLabel("Shot \(index + 1) of \(count)")
            LieKeypad(
                value: lieBinding(at: index),
                modifier: modifierBinding(at: index),
                target: "Green",
                extraTopLeft: inButton(at: index)
            )
            if Self.showsTransitionDistance(after: index, count: count) {
                VStack(alignment: .leading, spacing: 6) {
                    SubLabel("Landed at (from pin)")
                    DistanceWheel(
                        value: transitionDistanceBinding(after: index),
                        range: 1...150,
                        step: 1,
                        majorEvery: 10,
                        unit: "YDS"
                    )
                }
                .padding(.top, 10)
            }
        }
        .padding(.top, BrutalistSpacing.m)
    }

    static func showsTransitionDistance(after index: Int, count: Int) -> Bool {
        index >= 0 && index < count - 1
    }

    // MARK: - Per-slot bindings

    private func inButton(at index: Int) -> LieKeypad.AuxButton {
        LieKeypad.AuxButton(
            label: "IN",
            isActive: state.isARGIn(slot: index, at: holeIndex)
        ) { state.markARGIn(slot: index, at: holeIndex) }
    }

    private func lieBinding(at index: Int) -> Binding<String?> {
        Binding(
            get: { entry(at: index)?.lie },
            set: { newValue in
                mutateEntry(at: index) { $0.lie = newValue }
            }
        )
    }

    private func modifierBinding(at index: Int) -> Binding<String?> {
        Binding(
            get: { entry(at: index)?.lieModifier },
            set: { newValue in
                mutateEntry(at: index) { $0.lieModifier = newValue }
            }
        )
    }

    private func transitionDistanceBinding(after index: Int) -> Binding<Int?> {
        Binding(
            get: { state.argStartDistance(slot: index + 1, at: holeIndex) },
            set: { state.setARGTransitionDistance($0, after: index, at: holeIndex) }
        )
    }

    private func entry(at index: Int) -> ARGShotEntry? {
        guard state.entries.indices.contains(holeIndex) else { return nil }
        let entries = state.entries[holeIndex].argShots ?? []
        return entries.indices.contains(index) ? entries[index] : nil
    }

    /// Mutates the ARG entry at `index`, lazily growing the array so
    /// the user can fill slots in any order. The array is normalized
    /// to the inferred count so stale slots vanish when strokes drop.
    private func mutateEntry(at index: Int, _ apply: (inout ARGShotEntry) -> Void) {
        guard state.entries.indices.contains(holeIndex) else { return }
        var current = state.entries[holeIndex].argShots ?? []
        while current.count <= index {
            current.append(ARGShotEntry())
        }
        apply(&current[index])
        let inferred = state.inferredARGCount(at: holeIndex)
        if current.count > inferred {
            current = Array(current.prefix(inferred))
        }
        state.entries[holeIndex].argShots = current.isEmpty ? nil : current
    }
}
