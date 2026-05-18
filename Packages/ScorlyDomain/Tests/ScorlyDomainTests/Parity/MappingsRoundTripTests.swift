import Foundation
import Testing
@testable import ScorlyDomain

/// Exhaustive round-trip parity for every UI/DB enum mapping.
///
/// Plan invariant covered: "Mapping round-trips for every UI/DB enum
/// pairing" (Phase B7). Every case of every enum that has a mapping
/// helper is round-tripped through `Mappings`; every v1 alias and
/// "N/A" sentinel is verified.
struct MappingsRoundTripTests {
    // MARK: - RoundType

    @Test("Every RoundType case round-trips through uiLabel ↔ roundType(fromUILabel:)")
    func roundTypeRoundTripsExhaustively() {
        for type in RoundType.allCases {
            let label = Mappings.uiLabel(for: type)
            let parsed = Mappings.roundType(fromUILabel: label)
            #expect(parsed == type, "RoundType \(type) failed round-trip via '\(label)'")
        }
    }

    @Test("RoundType 'Competitive' resolves to .competitive")
    func roundTypeCompetitive() {
        #expect(Mappings.roundType(fromUILabel: "Competitive") == .competitive)
        // Whitespace tolerance.
        #expect(Mappings.roundType(fromUILabel: "  Competitive  ") == .competitive)
    }

    @Test("RoundType returns nil for unknown labels")
    func roundTypeUnknownReturnsNil() {
        #expect(Mappings.roundType(fromUILabel: "GibberishRound") == nil)
    }

    // MARK: - RoundFormat

    @Test("Every RoundFormat case round-trips through uiLabel ↔ roundFormat(fromUILabel:)")
    func roundFormatRoundTripsExhaustively() {
        for format in RoundFormat.allCases {
            let label = Mappings.uiLabel(for: format)
            let parsed = Mappings.roundFormat(fromUILabel: label)
            #expect(parsed == format, "RoundFormat \(format) failed round-trip via '\(label)'")
        }
    }

    @Test("RoundFormat — Stableford is first-class and round-trips")
    func roundFormatStableford() {
        #expect(Mappings.roundFormat(fromUILabel: "Stableford") == .stableford)
        #expect(Mappings.roundFormat(fromUILabel: "  Stableford  ") == .stableford)
    }

    @Test("RoundFormat returns nil for unknown labels")
    func roundFormatUnknownReturnsNil() {
        #expect(Mappings.roundFormat(fromUILabel: "Skins") == nil)
    }

    // MARK: - Conditions ↔ CSV

    @Test("Every single Conditions flag round-trips through CSV")
    func conditionsSingleFlagRoundTrip() {
        for entry in Conditions.labeledFlags {
            let csv = Mappings.csv(for: entry.flag)
            let parsed = Mappings.conditions(fromCSV: csv)
            #expect(parsed == entry.flag, "Flag for '\(entry.label)' failed round-trip")
        }
    }

    @Test("Empty Conditions ↔ empty CSV string")
    func emptyConditionsRoundTrip() {
        #expect(Mappings.csv(for: Conditions()).isEmpty)
        #expect(Mappings.conditions(fromCSV: "") == Conditions())
    }

    @Test("All-flags Conditions round-trips, preserving labeledFlags order")
    func allFlagsConditionsRoundTrip() {
        var all = Conditions()
        for entry in Conditions.labeledFlags {
            all.formUnion(entry.flag)
        }
        let csv = Mappings.csv(for: all)
        let parsed = Mappings.conditions(fromCSV: csv)
        #expect(parsed == all)

        // CSV ordering matches Conditions.labeledFlags declaration order
        // exactly — important so two equal Conditions values always
        // serialize to byte-identical CSVs (DB compare-friendly).
        let expectedOrder = Conditions.labeledFlags.map(\.label).joined(separator: ",")
        #expect(csv == expectedOrder)
    }

    @Test("Conditions parser ignores unknown tokens and tolerates whitespace")
    func conditionsParserForwardCompatible() {
        // Find a known label so the partial parse below is meaningful.
        guard let firstLabel = Conditions.labeledFlags.first?.label else {
            Issue.record("Conditions.labeledFlags is empty — test premise broken")
            return
        }
        let parsed = Mappings.conditions(fromCSV: " \(firstLabel) , FutureFlag , ")
        let expected = Conditions.labeledFlags[0].flag
        #expect(parsed == expected)
    }

    // MARK: - v1 shot location → Lie

    @Test("Every documented v1 shot-location string maps to the expected Lie")
    func v1ShotLocationsExhaustively() {
        let expectations: [(String, Lie)] = [
            ("Fairway", .fairway),
            ("Left", .roughLeft),
            ("Right", .roughRight),
            ("Short", .recoveryShort),
            ("Long", .recoveryLong),
            ("Out Left", .recoveryLeft),
            ("Out Right", .recoveryRight),
            ("Out Short", .recoveryShort),
            ("Out Long", .recoveryLong),
            ("Bunker Left", .bunkerLeft),
            ("Bunker Right", .bunkerRight),
            ("Bunker Short", .bunkerShort),
            ("Bunker Long", .bunkerLong),
            ("Green", .green),
        ]
        for (raw, expected) in expectations {
            #expect(
                Mappings.lie(fromV1ShotLocation: raw) == expected,
                "Shot location '\(raw)' should map to \(expected)"
            )
            // Whitespace-tolerant.
            #expect(Mappings.lie(fromV1ShotLocation: "  \(raw)  ") == expected)
        }
    }

    @Test("v1 'N/A' sentinel and unknown strings return nil")
    func v1NASentinelReturnsNil() {
        #expect(Mappings.lie(fromV1ShotLocation: "N/A") == nil)
        #expect(Mappings.lie(fromV1ShotLocation: "") == nil)
        #expect(Mappings.lie(fromV1ShotLocation: "Beach") == nil)
    }

    // MARK: - HolesPlayed (rawValue is its own UI label — no Mappings entry,

    // but the round-trip property still has to hold)

    @Test("HolesPlayed rawValue round-trips via init(rawValue:)")
    func holesPlayedRawValueRoundTrip() {
        for value in HolesPlayed.allCases {
            #expect(HolesPlayed(rawValue: value.rawValue) == value)
        }
    }

    @Test("WalkingVsRiding rawValue round-trips via init(rawValue:)")
    func walkingVsRidingRawValueRoundTrip() {
        for value in WalkingVsRiding.allCases {
            #expect(WalkingVsRiding(rawValue: value.rawValue) == value)
        }
    }

    @Test("PinPosition rawValue round-trips via init(rawValue:)")
    func pinPositionRawValueRoundTrip() {
        for value in PinPosition.allCases {
            #expect(PinPosition(rawValue: value.rawValue) == value)
        }
    }
}
