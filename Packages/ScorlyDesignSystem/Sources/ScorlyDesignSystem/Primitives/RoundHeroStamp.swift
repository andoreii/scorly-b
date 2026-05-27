import SwiftUI

/// Inverse dark stamp summarising one round: top row of mono metadata,
/// hairline divider, course name + caption on the left, big score +
/// par delta on the right. Used as the hero on Round Detail (and,
/// later, on Sign & File once that screen is unified).
///
/// Accepts pre-formatted strings only — no domain types — so the same
/// view can be driven by either a `CompletedRound` (Round Detail) or
/// the live `RoundPlayState` (Sign & File) without either feature
/// importing the other.
public struct RoundHeroStamp: View {
    private let dateLabel: String
    private let refLabel: String
    private let courseName: String
    private let caption: String
    private let score: Int
    private let parLabel: String

    public init(
        dateLabel: String,
        refLabel: String,
        courseName: String,
        caption: String,
        score: Int,
        parLabel: String
    ) {
        self.dateLabel = dateLabel
        self.refLabel = refLabel
        self.courseName = courseName
        self.caption = caption
        self.score = score
        self.parLabel = parLabel
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            BrutalistColor.invBg
            CornerMarks(inset: 6, color: BrutalistColor.invFg)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(dateLabel)
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.invFg)
                    Spacer()
                    Text(refLabel)
                        .font(BrutalistType.monoLabel)
                        .kerning(1.0)
                        .foregroundStyle(BrutalistColor.invFg)
                }
                Rectangle()
                    .fill(BrutalistColor.invFg.opacity(0.35))
                    .frame(height: 1)
                    .padding(.vertical, BrutalistSpacing.m)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(courseName)
                            .font(BrutalistType.rowTitle)
                            .kerning(-0.4)
                            .foregroundStyle(BrutalistColor.invFg)
                            .lineLimit(2)
                        Text(caption)
                            .font(BrutalistType.monoLabel)
                            .kerning(0.6)
                            .foregroundStyle(BrutalistColor.invMuted)
                            .lineLimit(2)
                    }
                    Spacer(minLength: BrutalistSpacing.m)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(score)")
                            .font(BrutalistType.sans(.bold, size: 72))
                            .kerning(-2.4)
                            .monospacedDigit()
                            .foregroundStyle(BrutalistColor.invFg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(parLabel)
                            .font(BrutalistType.monoCaption)
                            .kerning(0.6)
                            .foregroundStyle(BrutalistColor.invFg)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
    }
}
