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

struct DistanceDialConfigurationTests {
    @Test("Yard dial starts at zero and uses wider drag spacing")
    func yardConfiguration() {
        let unit = DistanceDial.Unit.yards

        #expect(unit.range == 0...340)
        #expect(unit.pointsPerUnit == 8)
        #expect(unit.isMajorMark(10))
        #expect(unit.isMidMark(5))
        #expect(unit.labels(for: 10).top == "10")
        #expect(unit.labels(for: 10).bottom == nil)
    }

    @Test("Putt dial labels every third foot with distance and ordinal")
    func puttConfiguration() {
        let unit = DistanceDial.Unit.feet

        #expect(unit.range == 0...60)
        #expect(!unit.isMajorMark(0))
        #expect(unit.isMajorMark(3))
        #expect(unit.isMajorMark(18))
        #expect(!unit.isMidMark(5))
        #expect(unit.labels(for: 3).top == "3")
        #expect(unit.labels(for: 3).bottom == "1")
        #expect(unit.labels(for: 18).top == "18")
        #expect(unit.labels(for: 18).bottom == "6")
        #expect(unit.labels(for: 60).top == "60")
        #expect(unit.labels(for: 60).bottom == "20")
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

struct ScoreTraceTrendsSummaryTests {
    @Test("Score trace summary labels and averages every round below the 20-round cap")
    func summaryUsesAvailableRoundsBelowCap() {
        let summary = ScoreTraceTrendsSummary(scores: [78, 80, 82])

        #expect(summary.averageLabel == "LAST 3 AVG")
        #expect(summary.average == 80)
    }

    @Test("Score trace summary caps its label and average at the latest 20 rounds")
    func summaryCapsAtTwentyRounds() {
        let summary = ScoreTraceTrendsSummary(scores: Array(1...25))

        #expect(summary.averageLabel == "LAST 20 AVG")
        #expect(summary.average == 15.5)
    }

    @Test("Score trace average trend treats lower scoring as improving")
    func averageTrendMapsScoreMovementToForm() {
        #expect(ScoreTraceAverageTrend(delta: -1.4) == .improving)
        #expect(ScoreTraceAverageTrend(delta: 1.4) == .worsening)
        #expect(ScoreTraceAverageTrend(delta: 0) == nil)
        #expect(ScoreTraceAverageTrend(delta: nil) == nil)
        #expect(ScoreTraceAverageTrend(delta: -1.4)?.pointsUp == false)
        #expect(ScoreTraceAverageTrend(delta: 1.4)?.pointsUp == true)
    }

    @Test("Score trace draw progress clamps and reveals dots as the line advances")
    func drawProgressClampsAndRevealsDots() {
        #expect(ScoreTraceDrawProgress(-0.5).value == 0)
        #expect(ScoreTraceDrawProgress(1.5).value == 1)
        #expect(ScoreTraceDrawProgress(0).visibleDotCount(totalPoints: 5) == 0)
        #expect(ScoreTraceDrawProgress(0.25).visibleDotCount(totalPoints: 5) == 2)
        #expect(ScoreTraceDrawProgress(0.5).visibleDotCount(totalPoints: 5) == 3)
        #expect(ScoreTraceDrawProgress(1).visibleDotCount(totalPoints: 5) == 5)
    }

    @Test("Delayed score traces begin undrawn")
    func delayedScoreTraceBeginsUndrawn() {
        #expect(ScoreTraceDrawProgress.initial(drawDelay: 0.18).value == 0)
        #expect(ScoreTraceDrawProgress.initial(drawDelay: nil).value == 1)
    }

    @Test("Score trace draw progress advances continuously over elapsed time")
    func scoreTraceDrawProgressAdvancesWithElapsedTime() {
        #expect(ScoreTraceDrawProgress.elapsed(-0.1, duration: 0.72).value == 0)
        #expect(ScoreTraceDrawProgress.elapsed(0.36, duration: 0.72).value == 0.5)
        #expect(ScoreTraceDrawProgress.elapsed(0.72, duration: 0.72).value == 1)
        #expect(ScoreTraceDrawProgress.elapsed(1, duration: 0.72).value == 1)
    }

    @Test("Animated numbers preserve target formatting at zero")
    func animatedNumberInitialValues() {
        #expect(AnimatedNumericText.initialValue(for: "+4.2") == "+0.0")
        #expect(AnimatedNumericText.initialValue(for: "31.3") == "0.0")
        #expect(AnimatedNumericText.initialValue(for: "62") == "0")
        #expect(AnimatedNumericText.initialValue(for: "-") == "-")
    }
}
