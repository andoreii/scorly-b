import ScorlyDesignSystem
import SwiftUI

/// Brief splash while `AuthService` restores the persisted session.
/// Just the wordmark, centered, no spinner. The pause is short enough
/// that a spinner is overkill and visually noisy.
public struct AuthLoadingView: View {
    public init() {}

    public var body: some View {
        ZStack {
            BrutalistColor.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 6) {
                Text("MODEL /B — SCORECARD OS")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.4)
                    .foregroundStyle(BrutalistColor.muted)
                Text(
                    "\(Text("SCOR\nLY").font(BrutalistType.wordmark).kerning(-3).foregroundColor(BrutalistColor.fg))\(Text("/B").font(BrutalistType.sans(.regular, size: 76)).foregroundColor(BrutalistColor.fg))"
                )
                .lineLimit(2)
            }
            .padding(.horizontal, BrutalistSpacing.pageHorizontal)
        }
    }
}
