import ScorlyDesignSystem
import SwiftUI

/// Placeholder for flow destinations not yet built, so transitions
/// remain visible end to end.
struct FlowPlaceholder: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ScreenShell {
            TopBar(left: title.uppercased(), right: "SCORLY/B  ®")

            HStack {
                Text("← BACK")
                    .font(BrutalistType.monoCaption)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.fg)
                    .brutalistTap(action: onBack)
                Spacer()
                Text("PLACEHOLDER")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
            .padding(.top, BrutalistSpacing.l)

            VStack(alignment: .leading, spacing: 0) {
                Text(
                    "\(Text(title.lowercased() + ".\n").font(BrutalistType.pageHero).kerning(-1.8).foregroundColor(BrutalistColor.fg))\(Text("coming next.").font(BrutalistType.pageHero).kerning(-1.8).foregroundColor(BrutalistColor.muted))"
                )
                .lineLimit(3)
            }
            .padding(.top, BrutalistSpacing.l)

            HBar(vMargin: BrutalistSpacing.xl)

            Text("THIS SCREEN LANDS IN THE FOLLOWING BUILD.")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.dim)
        }
    }
}
