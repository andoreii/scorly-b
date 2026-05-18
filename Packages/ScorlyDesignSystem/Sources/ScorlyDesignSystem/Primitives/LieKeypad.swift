import SwiftUI

/// Lie selection keypad. 5x5 cross — target in the center, miss arms,
/// then OB outer arms. A modifier button (Bunker / Water) appears
/// below once a Miss or OB is selected.
public struct LieKeypad: View {
    @Binding private var value: String?
    private let target: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(value: Binding<String?>, target: String) {
        _value = value
        self.target = target
    }

    public var body: some View {
        VStack(spacing: 10) {
            let layout: [[String?]] = [
                [nil, nil, "OB Long", nil, nil],
                [nil, nil, "Miss Long", nil, nil],
                ["OB Left", "Miss Left", target, "Miss Right", "OB Right"],
                [nil, nil, "Miss Short", nil, nil],
                [nil, nil, "OB Short", nil, nil],
            ]
            VStack(spacing: 4) {
                ForEach(0..<5) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<5) { col in
                            cell(layout[row][col])
                        }
                    }
                }
            }
            if let modifier {
                Button {
                    Haptics.soft()
                    withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                        value = value == modifier.value ? nil : modifier.value
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("↳")
                            .font(BrutalistType.monoCaption)
                            .opacity(0.7)
                        Text(modifier.label)
                            .font(BrutalistType.blockTitle)
                            .kerning(1.2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(value == modifier.value ? BrutalistColor.fg : .clear)
                    .foregroundStyle(value == modifier.value ? BrutalistColor.bg : BrutalistColor.fg)
                    .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func cell(_ cell: String?) -> some View {
        if let cell {
            let active = value == cell
            let isCenter = cell == target
            let isOut = cell.hasPrefix("OB ")
            Button {
                Haptics.soft()
                withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                    value = active ? nil : cell
                }
            } label: {
                Text(Self.short[cell] ?? cell)
                    .font(BrutalistType.mono(isCenter ? .semibold : .medium, size: isCenter ? 12 : 9))
                    .kerning(0.4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(cellBackground(active: active, isCenter: isCenter, isOut: isOut))
                    .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
                    .overlay(Rectangle().stroke(isCenter ? BrutalistColor.rule : BrutalistColor.hair, lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 40)
        }
    }

    private func cellBackground(active: Bool, isCenter: Bool, isOut: Bool) -> Color {
        if active { return BrutalistColor.fg }
        if isCenter { return BrutalistColor.panel }
        if isOut { return BrutalistColor.panel2 }
        return .clear
    }

    private var modifier: (label: String, value: String)? {
        guard let value else { return nil }
        if value.hasPrefix("Miss ") || value == "Bunker" {
            return (label: "BUNKER", value: "Bunker")
        }
        if value.hasPrefix("OB ") || value == "Water Hazard" {
            return (label: "WATER", value: "Water Hazard")
        }
        return nil
    }

    public static let short: [String: String] = [
        "Fairway": "FW",
        "Green": "GRN",
        "Miss Left": "MISS L",
        "Miss Right": "MISS R",
        "Miss Long": "MISS Lg",
        "Miss Short": "MISS S",
        "OB Left": "OB L",
        "OB Right": "OB R",
        "OB Long": "OB Lg",
        "OB Short": "OB S",
        "Bunker": "BUNKER",
        "Water Hazard": "WATER",
    ]
}
