import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyFeatureHistory

struct HistoryFilterMappingTests {
    @Test("9 chip maps to both front9 and back9; 18 chip maps to eighteen")
    func holesMapping() {
        #expect(HistoryFilterMapping.holesSet(from: ["9"]) == [.front9, .back9])
        #expect(HistoryFilterMapping.holesSet(from: ["18"]) == [.eighteen])
        #expect(HistoryFilterMapping.holesSet(from: ["9", "18"]) == [.front9, .back9, .eighteen])
        #expect(HistoryFilterMapping.holesSet(from: []).isEmpty)
    }

    @Test("Edit-state round-trip preserves the default filter exactly")
    func editStateRoundTripDefault() {
        let original = AggregateRoundFilter.default
        let state = AggregateFilterEditState(from: original)
        #expect(state.toFilter() == original)
    }

    @Test("Edit-state holes label uses 18 for .eighteen and 9 for nines")
    func editStateHolesLabels() {
        let filter = AggregateRoundFilter(holesPlayed: [.eighteen, .front9])
        let state = AggregateFilterEditState(from: filter)
        // front9/back9 both collapse into a single "9" chip.
        #expect(state.holes == ["18", "9"])
    }

    @Test("Default filter has zero deviations")
    func defaultDeviationCountZero() {
        #expect(HistoryFilterMapping.deviationCount(from: .default) == 0)
    }

    @Test("Enabling scramble registers one deviation")
    func enablingScrambleCountsAsOne() {
        var f = AggregateRoundFilter.default
        f.formats.insert(.scramble)
        #expect(HistoryFilterMapping.deviationCount(from: f) == 1)
    }

    @Test("Clearing formats and adding a tee shows two deviations")
    func multipleDeviations() {
        var f = AggregateRoundFilter.default
        f.formats = []
        f.teeNames = ["White"]
        #expect(HistoryFilterMapping.deviationCount(from: f) == 2)
    }

    @Test("Eligible default excludes scramble, 9-hole, missing format rounds")
    func defaultEligibility() {
        let stroke18 = makeRound(format: .stroke, holes: .eighteen)
        let stableford18 = makeRound(format: .stableford, holes: .eighteen)
        let match18 = makeRound(format: .match, holes: .eighteen)
        let scramble18 = makeRound(format: .scramble, holes: .eighteen)
        let other18 = makeRound(format: .other, holes: .eighteen)
        let stroke9 = makeRound(format: .stroke, holes: .front9)
        let missingFormat = makeRound(format: nil, holes: .eighteen)
        let all = [stroke18, stableford18, match18, scramble18, other18, stroke9, missingFormat]

        let kept = all.eligible(for: .default)
        #expect(kept.contains(stroke18))
        #expect(kept.contains(stableford18))
        #expect(kept.contains(match18))
        #expect(!kept.contains(scramble18))
        #expect(!kept.contains(other18))
        #expect(!kept.contains(stroke9))
        #expect(!kept.contains(missingFormat))
    }

    @Test("Adding scramble to the filter pulls scramble rounds back in")
    func scrambleOptIn() {
        let scramble18 = makeRound(format: .scramble, holes: .eighteen)
        var filter = AggregateRoundFilter.default
        filter.formats.insert(.scramble)
        #expect([scramble18].eligible(for: filter).contains(scramble18))
    }

    @Test("Clearing the formats set includes all formats including missing")
    func clearedFormatsIncludesAll() {
        let scramble18 = makeRound(format: .scramble, holes: .eighteen)
        let missing18 = makeRound(format: nil, holes: .eighteen)
        let filter = AggregateRoundFilter(holesPlayed: [.eighteen])
        let kept = [scramble18, missing18].eligible(for: filter)
        #expect(kept.contains(scramble18))
        #expect(kept.contains(missing18))
    }

    // MARK: - Helpers

    private func makeRound(format: RoundFormat?, holes: HolesPlayed) -> CompletedRound {
        CompletedRound(
            id: UUID(),
            datePlayed: Date(timeIntervalSince1970: 0),
            par: 72,
            totalScore: 90,
            holesPlayed: holes,
            roundType: nil,
            roundFormat: format
        )
    }
}
