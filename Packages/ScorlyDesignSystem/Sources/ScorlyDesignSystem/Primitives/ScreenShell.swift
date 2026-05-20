import SwiftUI

/// Page-level container. Bone-cream ground, safe-area padding,
/// horizontal padding 18. Wrap every screen in this so the iOS status
/// bar never overlaps content.
///
/// `scrollable` defaults to `true` — the standard idiom is a vertical
/// scroll. Set to `false` for fixed-layout landing screens (Home),
/// where content must fit above the fold; content is laid out in a
/// non-scrolling VStack that fills the safe area exactly.
public struct ScreenShell<Content: View>: View {
    private let scrollable: Bool
    private let content: () -> Content

    public init(
        scrollable: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.scrollable = scrollable
        self.content = content
    }

    public var body: some View {
        Group {
            if scrollable {
                ScrollView(.vertical, showsIndicators: false) {
                    column
                }
            } else {
                column
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .background(BrutalistColor.bg.ignoresSafeArea())
        .foregroundStyle(BrutalistColor.fg)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BrutalistSpacing.pageHorizontal)
        .padding(.top, BrutalistSpacing.safeTop)
        .padding(.bottom, BrutalistSpacing.safeBottom)
    }
}
