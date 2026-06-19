import CoreGraphics
import Testing
@testable import ScorlyDesignSystem

struct TargetFieldClassifierTests {
    @Test("Fairway radar exposes all four directional labels")
    @MainActor
    func fairwayAxisLabels() {
        #expect(TargetField.axisLabelTexts(for: .fairway) == ["LONG", "SHORT", "LEFT", "RIGHT"])
    }

    @Test("Fairway accepts distinct points inside its shortened corridor")
    func fairwayAcceptsContinuousInteriorPoints() {
        let first = TargetFieldClassifier.classify(mode: .fairway, x: 140, y: 110)
        let second = TargetFieldClassifier.classify(mode: .fairway, x: 160, y: 180)

        #expect(first.value == "Fairway")
        #expect(second.value == "Fairway")
        #expect(first.pos != second.pos)
    }

    @Test("Fairway classifies vertical misses as long and short")
    func fairwayClassifiesVerticalMisses() {
        #expect(TargetFieldClassifier.classify(mode: .fairway, x: 150, y: 60).value == "Miss Long")
        #expect(TargetFieldClassifier.classify(mode: .fairway, x: 150, y: 240).value == "Miss Short")
    }

    @Test("Fairway corner misses use the dominant axis")
    func fairwayUsesDominantAxis() {
        #expect(TargetFieldClassifier.classify(mode: .fairway, x: 35, y: 90).value == "Miss Left")
        #expect(TargetFieldClassifier.classify(mode: .fairway, x: 105, y: 35).value == "Miss Long")
    }

    @Test("Approach preserves exact positions across green and miss outcomes")
    func greenPreservesExactPositions() {
        let green = TargetFieldClassifier.classify(mode: .green, x: 110, y: 148)
        let miss = TargetFieldClassifier.classify(mode: .green, x: 10, y: 148)

        #expect(green.value == "Green")
        #expect(green.pos == CGPoint(x: 110.0 / 300.0, y: 148.0 / 300.0))
        #expect(miss.value == "Miss Left")
        #expect(miss.pos == CGPoint(x: 10.0 / 300.0, y: 148.0 / 300.0))
    }
}
