import ScorlyDesignSystem
import SwiftUI

/// Horizontal segmented bar showing the share of holes in each score
/// bucket (eagle+ / birdie / par / bogey / dbl+), with a mono caption
/// row below listing each bucket's exact count. No color — weight
/// contrast does the work, with par at a soft fill and further-from-par
/// buckets darkening.
struct DistributionBar: View {
    let total: Int
    let counts: [ScoreBucket: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            bar
            captions
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let segments = ScoreBucket.allCases
            ZStack(alignment: .leading) {
                Rectangle().stroke(BrutalistColor.rule, lineWidth: 1)
                HStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { idx, bucket in
                        let count = counts[bucket] ?? 0
                        let share = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .fill(fill(for: bucket))
                            // mono pip in the segment when it's wide enough to fit.
                            if share * width > 38 {
                                Text(bucket.rawValue)
                                    .font(BrutalistType.monoMicro)
                                    .kerning(0.6)
                                    .foregroundStyle(textColor(for: bucket))
                                    .padding(.leading, 6)
                                    .padding(.top, 6)
                            }
                        }
                        .frame(width: max(0, share * width), height: 44)
                        .overlay(alignment: .trailing) {
                            if idx < segments.count - 1, share > 0 {
                                Rectangle()
                                    .fill(BrutalistColor.rule)
                                    .frame(width: 1)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 44)
    }

    private var captions: some View {
        HStack(spacing: 0) {
            ForEach(Array(ScoreBucket.allCases.enumerated()), id: \.offset) { _, bucket in
                let count = counts[bucket] ?? 0
                VStack(alignment: .leading, spacing: 2) {
                    Text(bucket.rawValue)
                        .font(BrutalistType.monoMicro)
                        .kerning(0.6)
                        .foregroundStyle(BrutalistColor.muted)
                    Text("\(count)")
                        .font(BrutalistType.mono(.semibold, size: 12))
                        .monospacedDigit()
                        .foregroundStyle(BrutalistColor.fg)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Par sits at the lightest fill; eagles and double-bogeys+ push to
    /// opposite ink extremes.
    private func fill(for bucket: ScoreBucket) -> Color {
        switch bucket {
        case .eagleOrBetter: BrutalistColor.fg
        case .birdie: BrutalistColor.fg.opacity(0.80)
        case .par: BrutalistColor.panel2
        case .bogey: BrutalistColor.fg.opacity(0.55)
        case .doublePlus: BrutalistColor.fg.opacity(0.90)
        }
    }

    private func textColor(for bucket: ScoreBucket) -> Color {
        switch bucket {
        case .par: BrutalistColor.muted
        case .eagleOrBetter, .birdie, .bogey, .doublePlus: BrutalistColor.invFg
        }
    }
}
