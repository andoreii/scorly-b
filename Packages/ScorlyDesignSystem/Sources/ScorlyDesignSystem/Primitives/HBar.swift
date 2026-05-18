import SwiftUI

/// Hairline horizontal rule. The brutalist period at the end of a
/// section.
public struct HBar: View {
    private let weight: CGFloat
    private let color: Color
    private let vMargin: CGFloat

    public init(
        weight: CGFloat = 1,
        color: Color = BrutalistColor.rule,
        vMargin: CGFloat = 12
    ) {
        self.weight = weight
        self.color = color
        self.vMargin = vMargin
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: weight)
            .padding(.vertical, vMargin)
    }
}
