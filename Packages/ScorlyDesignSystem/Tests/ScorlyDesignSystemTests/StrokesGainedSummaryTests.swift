import Testing
@testable import ScorlyDesignSystem

struct StrokesGainedSummaryTests {
    @Test("Compact summary exposes only best and worst category cells")
    func compactSummaryContainsOnlyExtremes() {
        let values = SGCardValues(
            ott: 0.25,
            app: 1.86,
            arg: -0.50,
            putt: -2.71,
            total: -1.10
        )

        let items = SGSummaryItem.items(for: values, style: .categoryExtremes, referenceLabel: "VS SCRATCH")
        let fullItems = SGSummaryItem.items(for: values, style: .full, referenceLabel: "VS PERSONAL AVG")

        #expect(items.map(\.label) == ["BEST CATEGORY", "WORST CATEGORY"])
        #expect(items.map(\.title) == ["APPROACH", "PUTTING"])
        #expect(fullItems.map(\.label) == ["BEST CATEGORY", "WORST CATEGORY", "NET VS PERSONAL AVG"])
    }

    @Test("Spacious breakdown allocates more horizontal room to the x axis")
    func spaciousBreakdownExpandsPlotWidth() {
        #expect(SGBreakdownDensity.standard.rowHeight == 38)
        #expect(SGBreakdownDensity.spacious.rowHeight > SGBreakdownDensity.standard.rowHeight)
        #expect(!SGBreakdownDensity.standard.usesStackedRows)
        #expect(SGBreakdownDensity.spacious.usesStackedRows)
        #expect(SGBreakdownDensity.standard.showsCategoryCodes)
        #expect(!SGBreakdownDensity.spacious.showsCategoryCodes)
        #expect(!SGBreakdownDensity.standard.repeatsAxisTicksPerRow)
        #expect(SGBreakdownDensity.spacious.repeatsAxisTicksPerRow)
        #expect(SGBreakdownDensity.standard.showsHeaderDivider)
        #expect(!SGBreakdownDensity.spacious.showsHeaderDivider)
        #expect(SGBreakdownDensity.spacious.rowSpacing == BrutalistSpacing.xxs)
        #expect(SGBreakdownDensity.spacious.valueColumnWidth < SGBreakdownDensity.standard.valueColumnWidth)
        #expect(SGBreakdownDensity.spacious.trackHorizontalPadding < SGBreakdownDensity.standard.trackHorizontalPadding)
        #expect(SGBreakdownDensity.spacious.labelTrailingPadding < SGBreakdownDensity.standard.labelTrailingPadding)
        #expect(SGBreakdownDensity.standard.finalRowBottomPadding == 0)
        #expect(SGBreakdownDensity.spacious.finalRowBottomPadding == BrutalistSpacing.m)
        #expect(SGBreakdownDensity.spacious.legendTopPadding == BrutalistSpacing.l)
    }
}
