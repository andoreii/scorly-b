import SwiftUI

/// Big stroke / score stepper. 38pt buttons, 64pt numeric value.
public struct BrutalistStepper: View {
    @Binding private var value: Int
    private let range: ClosedRange<Int>

    public init(value: Binding<Int>, range: ClosedRange<Int>) {
        _value = value
        self.range = range
    }

    public var body: some View {
        HStack(spacing: 14) {
            stepButton("-", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }
            Text("\(value)")
                .font(BrutalistType.stepperValue)
                .kerning(-2.4)
                .monospacedDigit()
                .frame(minWidth: 70)
                .contentTransition(.numericText())
            stepButton("+", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
    }

    @ViewBuilder
    private func stepButton(_ glyph: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.medium()
            withAnimation(Motion.snap) { action() }
        } label: {
            Text(glyph)
                .font(BrutalistType.mono(.medium, size: 20))
                .frame(width: 38, height: 38)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                .foregroundStyle(BrutalistColor.fg)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

/// Compact stepper button used inline (temperature, penalty count).
public struct SmallStep: View {
    private let glyph: String
    private let action: () -> Void

    public init(_ glyph: String, action: @escaping () -> Void) {
        self.glyph = glyph
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            Text(glyph)
                .font(BrutalistType.mono(.medium, size: 18))
                .frame(width: 36, height: 36)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                .foregroundStyle(BrutalistColor.fg)
        }
        .buttonStyle(.plain)
    }
}

/// Extra-compact 26x26 variant used inside per-cell stepper rows.
public struct TinyStep: View {
    private let glyph: String
    private let action: () -> Void

    public init(_ glyph: String, action: @escaping () -> Void) {
        self.glyph = glyph
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(glyph)
                .font(BrutalistType.mono(.medium, size: 14))
                .frame(width: 26, height: 26)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                .foregroundStyle(BrutalistColor.fg)
        }
        .buttonStyle(.plain)
    }
}
