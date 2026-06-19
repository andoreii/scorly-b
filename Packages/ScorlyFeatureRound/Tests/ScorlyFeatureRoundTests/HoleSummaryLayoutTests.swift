import Testing
@testable import ScorlyFeatureRound

struct HoleSummaryLayoutTests {
    @Test("Score block occupies one third of the summary card")
    func scoreBlockUsesMockupProportion() {
        #expect(HoleSummaryLayout.scoreWidth(availableWidth: 360) == 120)
        #expect(HoleSummaryLayout.scoreWidth(availableWidth: 321) == 107)
    }

    @Test("Summary card keeps the mockup header and body rhythm")
    func cardUsesCompactVerticalRhythm() {
        #expect(HoleSummaryLayout.headerHeight == 30)
        #expect(HoleSummaryLayout.bodyHeight == 78)
    }
}
