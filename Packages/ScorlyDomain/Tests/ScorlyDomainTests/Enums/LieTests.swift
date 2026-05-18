import Testing
@testable import ScorlyDomain

struct LieTests {
    @Test("Twelve cases — no more, no fewer")
    func caseCount() {
        #expect(Lie.allCases.count == 12)
    }

    @Test("Raw values match v1's DB-canonical labels")
    func rawValues() {
        let expected: [(Lie, String)] = [
            (.fairway, "Fairway"),
            (.roughLeft, "Rough Left"),
            (.roughRight, "Rough Right"),
            (.bunkerLeft, "Bunker Left"),
            (.bunkerRight, "Bunker Right"),
            (.bunkerShort, "Bunker Short"),
            (.bunkerLong, "Bunker Long"),
            (.recoveryLeft, "Recovery Left"),
            (.recoveryRight, "Recovery Right"),
            (.recoveryShort, "Recovery Short"),
            (.recoveryLong, "Recovery Long"),
            (.green, "Green"),
        ]
        for (lie, raw) in expected {
            #expect(lie.rawValue == raw)
            #expect(Lie(rawValue: raw) == lie)
        }
    }

    @Test("Decoding an unknown raw value fails")
    func decodingUnknownFails() {
        #expect(Lie(rawValue: "Tee Box") == nil)
        #expect(Lie(rawValue: "") == nil)
    }
}
