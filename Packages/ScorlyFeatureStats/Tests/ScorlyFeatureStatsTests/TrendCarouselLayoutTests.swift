import CoreGraphics
import Testing
@testable import ScorlyFeatureStats

struct TrendCarouselLayoutTests {
    @Test
    func usesFullCardWidthWhileKeepingTheNextCardVisible() {
        let layout = TrendCarouselLayout(containerWidth: 354)

        #expect(layout.dividerWidth == 354)
        #expect(layout.cardWidth == 354)
        #expect(layout.viewportWidth == 390)
        #expect(layout.scrollContentInset == 18)
        #expect(layout.stageOffset == -18)
        #expect(layout.visiblePeekWidth == 12)

        let twoCardContentWidth = (layout.scrollContentInset * 2)
            + (layout.cardWidth * 2)
            + layout.cardGap
        let terminalScrollOffset = twoCardContentWidth - layout.viewportWidth
        let nextCardAlignedOffset = layout.cardWidth + layout.cardGap

        #expect(terminalScrollOffset == nextCardAlignedOffset)
    }
}
