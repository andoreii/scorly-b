import Testing
@testable import ScorlyDomain

/// Compact suite covering the small DB-canonical enums that share the
/// same shape (rawValue is the wire format).
struct RoundEnumTests {
    @Test("HolesPlayed raw values + derived hole counts")
    func holesPlayed() {
        #expect(HolesPlayed.front9.rawValue == "Front 9")
        #expect(HolesPlayed.back9.rawValue == "Back 9")
        #expect(HolesPlayed.eighteen.rawValue == "18")

        #expect(HolesPlayed.front9.holeCount == 9)
        #expect(HolesPlayed.back9.holeCount == 9)
        #expect(HolesPlayed.eighteen.holeCount == 18)

        #expect(HolesPlayed.front9.holeNumbers == Array(1...9))
        #expect(HolesPlayed.back9.holeNumbers == Array(10...18))
        #expect(HolesPlayed.eighteen.holeNumbers == Array(1...18))
    }

    @Test("RoundType — DB-canonical values only")
    func roundType() {
        #expect(RoundType.allCases.map(\.rawValue) == ["Practice", "Tournament", "Casual", "Competitive"])
    }

    @Test("RoundFormat — DB-canonical values only")
    func roundFormat() {
        #expect(RoundFormat.allCases.map(\.rawValue) == ["Stroke", "Match", "Scramble", "Stableford", "Other"])
    }

    @Test("TeeCategory — three buckets")
    func teeCategory() {
        #expect(TeeCategory.allCases.map(\.rawValue) == ["forward", "middle", "back"])
    }

    @Test("WalkingVsRiding — preserves multi-word labels")
    func walkingVsRiding() {
        #expect(WalkingVsRiding.pushCart.rawValue == "Push Cart")
        #expect(WalkingVsRiding(rawValue: "Push Cart") == .pushCart)
        #expect(WalkingVsRiding.allCases.count == 4)
    }

    @Test("PinPosition — three positions")
    func pinPosition() {
        #expect(PinPosition.allCases.map(\.rawValue) == ["Front", "Middle", "Back"])
    }
}
