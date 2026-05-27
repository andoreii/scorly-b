import Testing
@testable import ScorlyDesignSystem

struct BrutalistTokenTests {
    @Test("Spacing scale is the documented monotonic sequence")
    func spacingScaleIsMonotonic() {
        let scale: [Double] = [
            Double(BrutalistSpacing.xxs),
            Double(BrutalistSpacing.xs),
            Double(BrutalistSpacing.s),
            Double(BrutalistSpacing.sm),
            Double(BrutalistSpacing.m),
            Double(BrutalistSpacing.md),
            Double(BrutalistSpacing.l),
            Double(BrutalistSpacing.xl),
            Double(BrutalistSpacing.xxl),
            Double(BrutalistSpacing.xxxl),
        ]
        for index in 1..<scale.count {
            #expect(scale[index] > scale[index - 1])
        }
    }

    @Test("Safe-area constants — extras on top of system safe area")
    func safeAreaConstants() {
        // SwiftUI inserts the iOS status bar / home indicator clearance
        // automatically; ScreenShell adds nothing extra. The tokens
        // remain in the API for surfaces that may want a small buffer.
        #expect(BrutalistSpacing.safeTop == 0)
        #expect(BrutalistSpacing.safeBottom == 0)
        #expect(BrutalistSpacing.pageHorizontal == 18)
    }

    @Test("Font family raw values match bundled TTF basenames")
    func fontRawValuesMatchBundledFonts() {
        #expect(BrutalistType.Sans.light.rawValue == "Geist-Light")
        #expect(BrutalistType.Sans.regular.rawValue == "Geist-Regular")
        #expect(BrutalistType.Sans.medium.rawValue == "Geist-Medium")
        #expect(BrutalistType.Sans.semibold.rawValue == "Geist-SemiBold")
        #expect(BrutalistType.Sans.bold.rawValue == "Geist-Bold")
        #expect(BrutalistType.Mono.regular.rawValue == "JetBrainsMono-Regular")
        #expect(BrutalistType.Mono.medium.rawValue == "JetBrainsMono-Medium")
        #expect(BrutalistType.Mono.semibold.rawValue == "JetBrainsMono-SemiBold")
    }
}

struct PipScoringTests {
    @Test("Score label maps differences to authentic golf shorthand")
    func scoreLabelKnownValues() {
        #expect(ScoreLabel.text(strokes: 1, par: 3) == "ACE")
        #expect(ScoreLabel.text(strokes: 2, par: 4) == "EAGLE")
        #expect(ScoreLabel.text(strokes: 3, par: 4) == "BIRDIE")
        #expect(ScoreLabel.text(strokes: 4, par: 4) == "PAR")
        #expect(ScoreLabel.text(strokes: 5, par: 4) == "BOGEY")
        #expect(ScoreLabel.text(strokes: 6, par: 4) == "DOUBLE")
        #expect(ScoreLabel.text(strokes: 7, par: 4) == "TRIPLE")
        #expect(ScoreLabel.text(strokes: 8, par: 4) == "+4")
    }
}

struct LieKeypadShortTests {
    @Test("Every documented lie has a short label")
    @MainActor
    func everyLieHasShort() {
        let lies = [
            "Fairway", "Green",
            "Miss Left", "Miss Right", "Miss Long", "Miss Short",
            "OB Left", "OB Right", "OB Long", "OB Short",
            "Bunker", "Water Hazard",
        ]
        for lie in lies {
            #expect(LieKeypad.short[lie] != nil, "Missing short label for \(lie)")
        }
    }
}

struct ReviewChartValueTests {
    @Test("Putt distances map to the shared review buckets")
    func puttDistanceBuckets() {
        #expect(PuttDistanceBucket.bucket(forFeet: 0) == .feet0to3)
        #expect(PuttDistanceBucket.bucket(forFeet: 10) == .feet7to10)
        #expect(PuttDistanceBucket.bucket(forFeet: 31) == .feet31plus)
    }

    @Test("Scoring outcomes collapse to four review buckets")
    func scoringOutcomes() {
        #expect(ScoringOutcome.outcome(forVsPar: -2) == .birdiePlus)
        #expect(ScoringOutcome.outcome(forVsPar: -1) == .birdiePlus)
        #expect(ScoringOutcome.outcome(forVsPar: 0) == .par)
        #expect(ScoringOutcome.outcome(forVsPar: 1) == .bogey)
        #expect(ScoringOutcome.outcome(forVsPar: 2) == .doublePlus)
    }
}
