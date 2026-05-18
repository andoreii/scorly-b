import SwiftUI

/// Hole-by-hole bar chart. Over-par bars render fully opaque; par /
/// under render at 35% opacity. No color, just weight contrast.
public struct ScoreBars: View {
    private let scores: [Int]
    private let pars: [Int]

    public init(scores: [Int], pars: [Int]) {
        self.scores = scores
        self.pars = pars
    }

    public var body: some View {
        let maxValue = max(1, (zip(scores, pars).map { max($0.0, $0.1) }.max() ?? 0) + 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                let par = pars[index]
                let height = CGFloat(score) / CGFloat(maxValue)
                let over = score > par
                GeometryReader { geo in
                    Rectangle()
                        .fill(BrutalistColor.fg)
                        .opacity(over ? 1.0 : 0.35)
                        .frame(height: geo.size.height * height)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 48)
    }
}
