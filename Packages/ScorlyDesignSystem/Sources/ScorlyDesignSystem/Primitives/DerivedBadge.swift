import SwiftUI

/// Single auto-derived stat cell (GIR / FIR / 3PUTT / UP&DN). `flip`
/// = true means the stat is GOOD when false (3-putt). `dis` = true
/// dims the cell (FIR on par-3).
public struct DerivedBadge: View {
    private let label: String
    private let hit: Bool?
    private let flip: Bool
    private let isDisabled: Bool

    public init(label: String, hit: Bool?, flip: Bool = false, isDisabled: Bool = false) {
        self.label = label
        self.hit = hit
        self.flip = flip
        self.isDisabled = isDisabled
    }

    public var body: some View {
        let tone: Tone = isDisabled ? .off : tone(for: hit)
        VStack(spacing: 2) {
            Text(label)
                .font(BrutalistType.monoLabel)
                .kerning(0.6)
            Text(symbol)
                .font(BrutalistType.mono(.semibold, size: 11))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(tone == .good ? BrutalistColor.fg : .clear)
        .foregroundStyle(tone == .good ? BrutalistColor.bg : BrutalistColor.fg)
        .overlay(Rectangle().stroke(tone == .off ? BrutalistColor.hair : BrutalistColor.rule, lineWidth: 1))
        .opacity(isDisabled ? 0.35 : 1)
    }

    private enum Tone { case good, neutral, off }

    private func tone(for hit: Bool?) -> Tone {
        guard let hit else { return .off }
        let on = flip ? !hit : hit
        return on ? .good : .neutral
    }

    private var symbol: String {
        if isDisabled { return "—" }
        guard let hit else { return "·" }
        return hit ? "Y" : "N"
    }
}
