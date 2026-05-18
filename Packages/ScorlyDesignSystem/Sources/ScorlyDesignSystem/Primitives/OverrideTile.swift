import SwiftUI

/// Manual override tile (Up & Down, Sand Save). Shows current auto
/// value and lets the user override with YES / NO. Tapping the active
/// state clears the override and falls back to auto.
public struct OverrideTile: View {
    private let label: String
    private let auto: Bool
    @Binding private var value: Bool?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(label: String, auto: Bool, value: Binding<Bool?>) {
        self.label = label
        self.auto = auto
        _value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label.uppercased())
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                Spacer()
                Text("AUTO: \(auto ? "Y" : "N")\(value != nil ? " · MAN" : "")")
                    .font(BrutalistType.monoTick)
                    .kerning(0.6)
                    .foregroundStyle(BrutalistColor.dim)
            }
            HStack(spacing: 4) {
                pill("YES", on: true)
                pill("NO", on: false)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
    }

    @ViewBuilder
    private func pill(_ label: String, on: Bool) -> some View {
        let effective = value ?? auto
        let active = effective == on
        Button {
            Haptics.light()
            withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                value = value == on ? nil : on
            }
        } label: {
            Text(label)
                .font(BrutalistType.monoCaption)
                .kerning(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(active ? BrutalistColor.fg : .clear)
                .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
