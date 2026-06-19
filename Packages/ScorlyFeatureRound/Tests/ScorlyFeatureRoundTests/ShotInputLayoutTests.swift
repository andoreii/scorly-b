import Testing
@testable import ScorlyFeatureRound

struct ShotInputLayoutTests {
    @Test("Round Play sheets add no blank padding below their content")
    func sheetsHaveNoExtraBottomPadding() {
        #expect(RoundPlaySheetLayout.extraBottomPadding == 0)
    }

    @Test("Radar fills available sheet width inside its horizontal padding")
    func radarUsesAvailableWidth() {
        #expect(ShotInputLayout.radarSide(availableWidth: 390) == 374)
        #expect(ShotInputLayout.radarSide(availableWidth: 320) == 304)
    }

    @Test("Radar size never becomes negative")
    func radarSizeClampsAtZero() {
        #expect(ShotInputLayout.radarSide(availableWidth: 10) == 0)
    }
}
