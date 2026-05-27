import ScorlyDesignSystem
import SwiftUI

/// Shared header for every Trend-page card. Mirrors the
/// design-system Strokes Gained card: a mono uppercase meta label
/// above a sans hero title on the left, optional mono trailing tag
/// (N=count, etc.) on the right.
///
/// Using one component for all cards keeps the rhythm consistent and
/// makes future copy / typography tweaks a single-file change.
struct CardHeader: View {
    let meta: String
    let title: String
    let trailing: String?

    init(meta: String, title: String, trailing: String? = nil) {
        self.meta = meta
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(meta.uppercased())
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(title)
                    .font(BrutalistType.sans(.bold, size: 24))
                    .kerning(-0.6)
                    .foregroundStyle(BrutalistColor.fg)
            }
            Spacer(minLength: BrutalistSpacing.m)
            if let trailing {
                Text(trailing)
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.muted)
                    .monospacedDigit()
            }
        }
    }
}
