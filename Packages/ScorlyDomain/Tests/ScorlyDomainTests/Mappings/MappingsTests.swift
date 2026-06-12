import Testing
@testable import ScorlyDomain

struct MappingsTests {
    // MARK: - RoundType

    @Test("RoundType — DB-canonical labels round-trip")
    func roundTypeRoundTrip() {
        for roundType in RoundType.allCases {
            let label = Mappings.uiLabel(for: roundType)
            #expect(Mappings.roundType(fromUILabel: label) == roundType)
        }
    }

    @Test("RoundType — 'Competitive' resolves to .competitive")
    func roundTypeCompetitive() {
        #expect(Mappings.roundType(fromUILabel: "Competitive") == .competitive)
    }

    @Test("RoundType — surrounding whitespace tolerated")
    func roundTypeTrimsWhitespace() {
        #expect(Mappings.roundType(fromUILabel: "  Casual  ") == .casual)
        #expect(Mappings.roundType(fromUILabel: " Competitive ") == .competitive)
    }

    @Test("RoundType — unknown label yields nil")
    func roundTypeUnknown() {
        #expect(Mappings.roundType(fromUILabel: "Friendly") == nil)
        #expect(Mappings.roundType(fromUILabel: "") == nil)
    }

    // MARK: - RoundFormat

    @Test("RoundFormat — DB-canonical labels round-trip")
    func roundFormatRoundTrip() {
        for roundFormat in RoundFormat.allCases {
            let label = Mappings.uiLabel(for: roundFormat)
            #expect(Mappings.roundFormat(fromUILabel: label) == roundFormat)
        }
    }

    @Test("RoundFormat — Stableford is now first-class")
    func roundFormatStableford() {
        #expect(Mappings.roundFormat(fromUILabel: "Stableford") == .stableford)
        #expect(Mappings.roundFormat(fromUILabel: "  Stableford  ") == .stableford)
    }

    @Test("RoundFormat — database aliases normalize to canonical cases")
    func roundFormatDatabaseAliases() {
        #expect(Mappings.roundFormat(fromUILabel: "Stroke Play") == .stroke)
        #expect(Mappings.roundFormat(fromUILabel: "Match Play") == .match)
    }

    @Test("RoundFormat — unknown label yields nil")
    func roundFormatUnknown() {
        #expect(Mappings.roundFormat(fromUILabel: "BestBall") == nil)
        #expect(Mappings.roundFormat(fromUILabel: "") == nil)
    }

    // MARK: - Conditions ↔ CSV

    @Test("Conditions CSV — empty set serializes to empty string")
    func conditionsCSVEmpty() {
        #expect(Mappings.csv(for: Conditions()).isEmpty)
    }

    @Test("Conditions CSV — single flag")
    func conditionsCSVSingle() {
        #expect(Mappings.csv(for: .sunny) == "Sunny")
        #expect(Mappings.csv(for: .rainy) == "Rainy")
    }

    @Test("Conditions CSV — multi-flag preserves canonical order regardless of insertion order")
    func conditionsCSVCanonicalOrder() {
        let csv1 = Mappings.csv(for: [.sunny, .windy])
        let csv2 = Mappings.csv(for: [.windy, .sunny])
        #expect(csv1 == "Sunny,Windy")
        #expect(csv2 == "Sunny,Windy")
    }

    @Test("Conditions CSV — full set")
    func conditionsCSVFull() {
        let full: Conditions = [.sunny, .cloudy, .windy, .rainy]
        #expect(Mappings.csv(for: full) == "Sunny,Cloudy,Windy,Rainy")
    }

    @Test("Conditions CSV — round-trip every subset")
    func conditionsCSVRoundTripAllSubsets() {
        for mask in 0..<16 {
            let original = Conditions(rawValue: mask)
            let csv = Mappings.csv(for: original)
            let decoded = Mappings.conditions(fromCSV: csv)
            #expect(decoded == original)
        }
    }

    @Test("Conditions parse — tolerates whitespace around tokens")
    func conditionsParseTolerantWhitespace() {
        #expect(Mappings.conditions(fromCSV: "Sunny, Windy") == [.sunny, .windy])
        #expect(Mappings.conditions(fromCSV: " Sunny , Windy ") == [.sunny, .windy])
    }

    @Test("Conditions parse — silently drops unknown tokens")
    func conditionsParseDropsUnknown() {
        #expect(Mappings.conditions(fromCSV: "Sunny,Foggy,Windy") == [.sunny, .windy])
        #expect(Mappings.conditions(fromCSV: "Foggy,Hail") == Conditions())
    }

    @Test("Conditions parse — empty string")
    func conditionsParseEmpty() {
        #expect(Mappings.conditions(fromCSV: "") == Conditions())
    }

    // MARK: - Lie (v1 → v2)

    @Test("Lie — every v1 shot-location string maps to a v2 Lie")
    func lieAllV1Values() {
        let expected: [(v1: String, v2: Lie)] = [
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
        for (v1, v2) in expected {
            #expect(Mappings.lie(fromV1ShotLocation: v1) == v2)
        }
    }

    @Test("Lie — N/A and empty resolve to nil (no shot recorded)")
    func lieNilSentinels() {
        #expect(Mappings.lie(fromV1ShotLocation: "N/A") == nil)
        #expect(Mappings.lie(fromV1ShotLocation: "") == nil)
        #expect(Mappings.lie(fromV1ShotLocation: "   ") == nil)
    }

    @Test("Lie — unknown strings resolve to nil")
    func lieUnknown() {
        #expect(Mappings.lie(fromV1ShotLocation: "Tee Box") == nil)
        #expect(Mappings.lie(fromV1ShotLocation: "Water") == nil)
    }

    @Test("Lie — surrounding whitespace tolerated")
    func lieTrimsWhitespace() {
        #expect(Mappings.lie(fromV1ShotLocation: "  Fairway  ") == .fairway)
        #expect(Mappings.lie(fromV1ShotLocation: " Bunker Long ") == .bunkerLong)
    }
}
