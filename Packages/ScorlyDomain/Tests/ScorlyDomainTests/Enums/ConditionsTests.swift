import Testing
@testable import ScorlyDomain

struct ConditionsTests {
    @Test("Each flag has a distinct bit")
    func distinctBits() {
        let flags: [Conditions] = [.sunny, .cloudy, .windy, .rainy]
        let bits = Set(flags.map(\.rawValue))
        #expect(bits.count == flags.count)
    }

    @Test("Union and contains behave like a normal OptionSet")
    func unionAndContains() {
        let combo: Conditions = [.sunny, .windy]
        #expect(combo.contains(.sunny))
        #expect(combo.contains(.windy))
        #expect(!combo.contains(.cloudy))
        #expect(!combo.contains(.rainy))
    }

    @Test("Empty and full sets behave correctly")
    func emptyAndFull() {
        let empty = Conditions()
        #expect(empty.isEmpty)
        #expect(empty.rawValue == 0)

        let full: Conditions = [.sunny, .cloudy, .windy, .rainy]
        #expect(full.contains(.sunny))
        #expect(full.contains(.rainy))
    }

    @Test("Canonical ordering matches the v1 wire format")
    func canonicalOrder() {
        let labels = Conditions.labeledFlags.map(\.label)
        #expect(labels == ["Sunny", "Cloudy", "Windy", "Rainy"])
    }
}
