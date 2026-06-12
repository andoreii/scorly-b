import ScorlyDesignSystem
import SwiftUI

/// Horizontally-paged carousel where the active card matches the header
/// rule's width and adjacent cards peek in from the page gutters.
/// Slides report their height via a PreferenceKey; the carousel locks
/// the page frame to the tallest one.
struct TrendCarousel<Slide: Identifiable & Hashable, Content: View>: View {
    let title: String
    let slides: [Slide]
    let content: (Slide) -> Content
    /// Minimum height for the page frame before any slide measurement
    /// arrives. Prevents the carousel from collapsing on first render.
    private let minHeight: CGFloat

    @State private var measuredHeight: CGFloat = 0
    @State private var visibleSlideID: Slide.ID?

    init(
        title: String,
        slides: [Slide],
        minHeight: CGFloat = 280,
        @ViewBuilder content: @escaping (Slide) -> Content
    ) {
        self.title = title
        self.slides = slides
        self.minHeight = minHeight
        self.content = content
    }

    var body: some View {
        // Rule and card share content width; the stage alone draws into
        // ScreenShell's side gutters to keep card peeks.
        GeometryReader { proxy in
            let layout = TrendCarouselLayout(containerWidth: proxy.size.width)
            VStack(alignment: .leading, spacing: 8) {
                header
                HBar(vMargin: 2)
                    .frame(width: layout.dividerWidth, alignment: .leading)
                stage(layout: layout)
            }
        }
        // GeometryReader needs an explicit height, so mirror the
        // inner stage's measurement-driven sizing.
        .frame(height: outerHeight)
        .onPreferenceChange(SlideHeightPreference.self) { newHeight in
            measuredHeight = max(measuredHeight, newHeight)
        }
        .onAppear {
            if visibleSlideID == nil {
                visibleSlideID = slides.first?.id
            }
        }
    }

    /// Stage height plus fixed chrome (header + HBar + spacing) above it.
    private var outerHeight: CGFloat {
        let chromeHeight: CGFloat = 44 // mono header row + HBar + VStack spacing
        return max(measuredHeight, minHeight) + chromeHeight
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(BrutalistType.monoLabel)
                .kerning(1.0)
                .foregroundStyle(BrutalistColor.fg)
            Spacer()
            tickStrip
                .frame(width: tickWidth, height: 8)
            Text(indexLabel)
                .font(BrutalistType.monoMicro)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.muted)
                .monospacedDigit()
        }
    }

    private var tickStrip: some View {
        HStack(spacing: 4) {
            ForEach(0..<slides.count, id: \.self) { tick in
                Rectangle()
                    .fill(tick == currentIndex ? BrutalistColor.fg : BrutalistColor.hair)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var tickWidth: CGFloat {
        CGFloat(slides.count) * 14
    }

    private var indexLabel: String {
        let pad: (Int) -> String = { String(format: "%02d", $0) }
        return "\(pad(currentIndex + 1))/\(pad(slides.count))"
    }

    private var currentIndex: Int {
        guard let visibleSlideID,
              let idx = slides.firstIndex(where: { $0.id == visibleSlideID })
        else { return 0 }
        return idx
    }

    // MARK: - Stage

    @ViewBuilder
    private func stage(layout: TrendCarouselLayout) -> some View {
        if slides.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: layout.cardGap) {
                    ForEach(slides) { slide in
                        content(slide)
                            .frame(width: layout.cardWidth, alignment: .top)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .background(heightReporter)
                            .id(slide.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $visibleSlideID, anchor: .leading)
            .safeAreaPadding(.horizontal, layout.scrollContentInset)
            .frame(
                width: layout.viewportWidth,
                height: max(measuredHeight, minHeight),
                alignment: .leading
            )
            .offset(x: layout.stageOffset)
        }
    }

    private var heightReporter: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SlideHeightPreference.self,
                value: proxy.size.height
            )
        }
    }
}

/// Geometry for a carousel within ScreenShell's padded content column;
/// both gutters show a neighboring-card preview.
struct TrendCarouselLayout {
    let dividerWidth: CGFloat
    let cardWidth: CGFloat
    let viewportWidth: CGFloat
    let cardGap: CGFloat
    let scrollContentInset: CGFloat
    let stageOffset: CGFloat

    init(containerWidth: CGFloat) {
        let contentWidth = max(0, containerWidth)
        let pageGutter = BrutalistSpacing.pageHorizontal
        dividerWidth = contentWidth
        cardWidth = contentWidth
        cardGap = BrutalistSpacing.xs
        scrollContentInset = pageGutter
        viewportWidth = contentWidth + (pageGutter * 2)
        stageOffset = -pageGutter
    }

    var visiblePeekWidth: CGFloat {
        max(0, scrollContentInset - cardGap)
    }
}

/// Reports the tallest slide; `max` combine keeps it monotonic so the frame never shrinks.
private struct SlideHeightPreference: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
