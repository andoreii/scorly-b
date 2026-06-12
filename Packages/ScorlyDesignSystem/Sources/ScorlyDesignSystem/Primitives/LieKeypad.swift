import SwiftUI

/// Lie selection keypad. 5x5 cross: target center, miss arms, OB outer arms.
/// Water (bottom-left) pairs with an OB direction; Bunker (bottom-right) pairs with a Miss direction.
public struct LieKeypad: View {
    public struct AuxButton {
        public let label: String
        public let isActive: Bool
        public let action: () -> Void

        public init(label: String, isActive: Bool, action: @escaping () -> Void) {
            self.label = label
            self.isActive = isActive
            self.action = action
        }
    }

    @Binding private var value: String?
    @Binding private var modifier: String?
    private let target: String
    private let extraTopLeft: AuxButton?
    private let extraTopRight: AuxButton?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        value: Binding<String?>,
        modifier: Binding<String?>,
        target: String,
        extraTopLeft: AuxButton? = nil,
        extraTopRight: AuxButton? = nil
    ) {
        _value = value
        _modifier = modifier
        self.target = target
        self.extraTopLeft = extraTopLeft
        self.extraTopRight = extraTopRight
    }

    public var body: some View {
        let layout: [[String?]] = [
            [nil, nil, "OB Long", nil, nil],
            [nil, nil, "Miss Long", nil, nil],
            ["OB Left", "Miss Left", target, "Miss Right", "OB Right"],
            [nil, nil, "Miss Short", nil, nil],
            ["Water", nil, "OB Short", nil, "Bunker"],
        ]
        VStack(spacing: 4) {
            ForEach(0..<5) { row in
                HStack(spacing: 4) {
                    ForEach(0..<5) { col in
                        if row == 0, col == 0, let aux = extraTopLeft {
                            auxCell(aux)
                        } else if row == 0, col == 4, let aux = extraTopRight {
                            auxCell(aux)
                        } else {
                            cell(layout[row][col])
                        }
                    }
                }
            }
        }
        .onChange(of: value) { _, newValue in
            // Clear modifier if the directional pick moves off its domain, to avoid orphan modifiers.
            if newValue == nil {
                modifier = nil
                return
            }
            if modifier == "Bunker", !(newValue ?? "").hasPrefix("Miss ") {
                modifier = nil
            }
            if modifier == "Water", !(newValue ?? "").hasPrefix("OB ") {
                modifier = nil
            }
        }
    }

    @ViewBuilder
    private func cell(_ cell: String?) -> some View {
        if let cell {
            if cell == "Bunker" || cell == "Water" {
                modifierCell(cell)
            } else {
                directionCell(cell)
            }
        } else {
            Color.clear.frame(height: 40)
        }
    }

    private func directionCell(_ cell: String) -> some View {
        let active = value == cell
        let isCenter = cell == target
        let isOut = cell.hasPrefix("OB ")
        return Text(Self.short[cell] ?? cell)
            .font(BrutalistType.mono(isCenter ? .semibold : .medium, size: isCenter ? 12 : 9))
            .kerning(0.4)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(cellBackground(active: active, isCenter: isCenter, isOut: isOut))
            .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
            .overlay(Rectangle().stroke(isCenter ? BrutalistColor.rule : BrutalistColor.hair, lineWidth: 1))
            .brutalistTap {
                Haptics.soft()
                withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                    value = active ? nil : cell
                }
            }
    }

    private func modifierCell(_ cell: String) -> some View {
        let active = modifier == cell
        let enabled = modifierEnabled(cell)
        return Text(Self.short[cell] ?? cell)
            .font(BrutalistType.mono(.semibold, size: 9))
            .kerning(0.6)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(active ? BrutalistColor.fg : BrutalistColor.panel2)
            .foregroundStyle(active ? BrutalistColor.bg : BrutalistColor.fg)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            .opacity(enabled ? 1 : 0.35)
            .brutalistTap(disabled: !enabled) {
                Haptics.soft()
                withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                    modifier = active ? nil : cell
                }
            }
    }

    private func auxCell(_ aux: AuxButton) -> some View {
        Text(aux.label)
            .font(BrutalistType.mono(.semibold, size: 9))
            .kerning(0.4)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(aux.isActive ? BrutalistColor.fg : BrutalistColor.panel)
            .foregroundStyle(aux.isActive ? BrutalistColor.bg : BrutalistColor.fg)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))
            .brutalistTap {
                Haptics.soft()
                withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
                    aux.action()
                }
            }
    }

    private func modifierEnabled(_ cell: String) -> Bool {
        guard let value else { return false }
        switch cell {
        case "Bunker": return value.hasPrefix("Miss ")
        case "Water": return value.hasPrefix("OB ")
        default: return false
        }
    }

    private func cellBackground(active: Bool, isCenter: Bool, isOut: Bool) -> Color {
        if active { return BrutalistColor.fg }
        if isCenter { return BrutalistColor.panel }
        if isOut { return BrutalistColor.panel2 }
        return .clear
    }

    public static let short: [String: String] = [
        "Fairway": "FW",
        "Green": "GRN",
        "In": "IN",
        "Miss Left": "MISS L",
        "Miss Right": "MISS R",
        "Miss Long": "MISS Lg",
        "Miss Short": "MISS S",
        "OB Left": "OB L",
        "OB Right": "OB R",
        "OB Long": "OB Lg",
        "OB Short": "OB S",
        "Bunker": "BUNK",
        "Water": "WATER",
        "Water Hazard": "WATER",
    ]
}
