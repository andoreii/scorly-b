import SwiftUI

/// Page-level container. Bone-cream ground, safe-area padding,
/// horizontal padding 18. Wrap every screen in this so the iOS status
/// bar never overlaps content.
public struct ScreenShell<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BrutalistSpacing.pageHorizontal)
            .padding(.top, BrutalistSpacing.safeTop)
            .padding(.bottom, BrutalistSpacing.safeBottom)
        }
        .background(BrutalistColor.bg.ignoresSafeArea())
        .foregroundStyle(BrutalistColor.fg)
    }
}
