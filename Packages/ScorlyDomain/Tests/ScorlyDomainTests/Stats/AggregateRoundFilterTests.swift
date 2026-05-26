import Foundation
import Testing
@testable import ScorlyDomain

struct AggregateRoundFilterTests {
    @Test("Default includes 18-hole Stroke / Stableford / Match")
    func defaultIncludesCanonical() {
        let filter = AggregateRoundFilter.default
        #expect(filter.includes(round(format: .stroke, holes: .eighteen)))
        #expect(filter.includes(round(format: .stableford, holes: .eighteen)))
        #expect(filter.includes(round(format: .match, holes: .eighteen)))
    }

    @Test("Default excludes 18-hole Scramble and Other")
    func defaultExcludesScrambleAndOther() {
        let filter = AggregateRoundFilter.default
        #expect(!filter.includes(round(format: .scramble, holes: .eighteen)))
        #expect(!filter.includes(round(format: .other, holes: .eighteen)))
    }

    @Test("Default excludes 9-hole rounds even with eligible format")
    func defaultExcludesNineHole() {
        let filter = AggregateRoundFilter.default
        #expect(!filter.includes(round(format: .stroke, holes: .front9)))
        #expect(!filter.includes(round(format: .stroke, holes: .back9)))
    }

    @Test("Default excludes rounds with missing format")
    func defaultExcludesMissingFormat() {
        let filter = AggregateRoundFilter.default
        #expect(!filter.includes(round(format: nil, holes: .eighteen)))
    }

    @Test("Empty format set includes all formats including nil")
    func emptyFormatIncludesEverything() {
        let filter = AggregateRoundFilter(holesPlayed: [.eighteen])
        #expect(filter.includes(round(format: nil, holes: .eighteen)))
        #expect(filter.includes(round(format: .scramble, holes: .eighteen)))
        #expect(filter.includes(round(format: .other, holes: .eighteen)))
        // Holes restriction still applies.
        #expect(!filter.includes(round(format: .stroke, holes: .front9)))
    }

    @Test("Round-type restriction excludes nil round type when set is non-empty")
    func roundTypeExcludesNilWhenRestricted() {
        let filter = AggregateRoundFilter(
            holesPlayed: [.eighteen],
            formats: [.stroke],
            roundTypes: [.competitive]
        )
        #expect(filter.includes(round(format: .stroke, type: .competitive, holes: .eighteen)))
        #expect(!filter.includes(round(format: .stroke, type: .casual, holes: .eighteen)))
        #expect(!filter.includes(round(format: .stroke, type: nil, holes: .eighteen)))
    }

    @Test("Tee-name restriction matches by name and excludes nil when restricted")
    func teeNameRestriction() {
        let filter = AggregateRoundFilter(
            holesPlayed: [.eighteen],
            formats: [.stroke],
            teeNames: ["White"]
        )
        #expect(filter.includes(round(format: .stroke, holes: .eighteen, tee: "White")))
        #expect(!filter.includes(round(format: .stroke, holes: .eighteen, tee: "Black")))
        #expect(!filter.includes(round(format: .stroke, holes: .eighteen, tee: nil)))
    }

    @Test("Sequence extension preserves source order")
    func sequenceExtensionPreservesOrder() {
        let rounds = [
            round(format: .stroke, holes: .eighteen), // include
            round(format: .scramble, holes: .eighteen), // exclude
            round(format: .stableford, holes: .eighteen), // include
            round(format: .stroke, holes: .front9), // exclude (9 hole)
            round(format: .match, holes: .eighteen), // include
        ]
        let result = rounds.eligible(for: .default)
        #expect(result.count == 3)
        #expect(result.map(\.roundFormat) == [.stroke, .stableford, .match])
    }

    @Test("Codable round-trip preserves selections")
    func codableRoundTrip() throws {
        let filter = AggregateRoundFilter(
            holesPlayed: [.eighteen],
            formats: [.stroke, .match],
            roundTypes: [.casual],
            teeNames: ["White", "Yellow"]
        )
        let data = try JSONEncoder().encode(filter)
        let decoded = try JSONDecoder().decode(AggregateRoundFilter.self, from: data)
        #expect(decoded == filter)
    }

    // MARK: - Helpers

    private func round(
        format: RoundFormat?,
        type: RoundType? = nil,
        holes: HolesPlayed,
        tee: String? = nil
    ) -> CompletedRound {
        CompletedRound(
            id: UUID(),
            datePlayed: Date(timeIntervalSince1970: 0),
            par: 72,
            totalScore: 90,
            holesPlayed: holes,
            roundType: type,
            roundFormat: format,
            teeName: tee
        )
    }
}
