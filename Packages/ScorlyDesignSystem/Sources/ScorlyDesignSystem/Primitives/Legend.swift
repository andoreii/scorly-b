import SwiftUI

/// Symbol + caption pair used in the scorecard legends (BIRDIE+ /
/// PAR / BOGEY+).
public struct Legend<Symbol: View>: View {
    private let label: String
    private let symbol: () -> Symbol

    public init(label: String, @ViewBuilder symbol: @escaping () -> Symbol) {
        self.label = label
        self.symbol = symbol
    }

    public var body: some View {
        HStack(spacing: 4) {
            symbol()
            Text(label.uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
        }
    }
}
