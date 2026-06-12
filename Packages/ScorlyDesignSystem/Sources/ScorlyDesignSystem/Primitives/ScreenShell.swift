import SwiftUI

/// Page-level container with safe-area + horizontal padding. Wrap every screen in this.
/// `scrollable: false` for fixed-layout landing screens where content must fit above the fold.
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
