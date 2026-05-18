import Foundation
import Testing
@testable import ScorlyDomain

struct DistanceTests {
    @Test("DistanceUnit raw values are stable for UserDefaults")
    func unitRawValues() {
        #expect(DistanceUnit.yards.rawValue == "yards")
        #expect(DistanceUnit.meters.rawValue == "meters")
        #expect(DistanceUnit.yards.symbol == "yd")
        #expect(DistanceUnit.meters.symbol == "m")
    }

    @Test("Yards round-trip exactly")
    func yardsRoundTrip() {
        let dist = Distance(yards: 250)
        #expect(dist.yards == 250)
        #expect(dist.value(in: .yards) == 250)
    }

    @Test("Meters convert with international yard exact ratio")
    func metersConversion() {
        let dist = Distance(yards: 100)
        // 100 yd × 0.9144 = 91.44 m → rounds to 91
        #expect(dist.value(in: .meters) == 91)
        #expect(dist.meters == 91.44)
    }

    @Test("Constructing from meters rounds to nearest yard")
    func metersInputRounds() {
        // 100 m / 0.9144 = 109.361… yd → rounds to 109
        let dist = Distance(100, unit: .meters)
        #expect(dist.yards == 109)

        // Exact: 91.44 m == 100 yd
        let exact = Distance(91.44, unit: .meters)
        #expect(exact.yards == 100)
    }

    @Test("Constructing from yards Double rounds to nearest int")
    func yardsInputRounds() {
        #expect(Distance(149.4, unit: .yards).yards == 149)
        #expect(Distance(149.6, unit: .yards).yards == 150)
    }

    @Test("Negative input is clamped to zero — no negative shot distances")
    func negativeClamped() {
        #expect(Distance(yards: -50).yards == 0)
        #expect(Distance(-10, unit: .meters).yards == 0)
    }

    @Test("Comparable by canonical yards")
    func comparable() {
        let short = Distance(yards: 100)
        let mid = Distance(yards: 150)
        let long = Distance(yards: 200)
        #expect(short < long)
        #expect(long > short)
        #expect(mid == Distance(yards: 150))
    }

    @Test("Codable round-trips by canonical yards")
    func codableRoundTrip() throws {
        let original = Distance(yards: 175)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Distance.self, from: data)
        #expect(decoded == original)
    }

    @Test("Formatted output uses unit symbol")
    func formattedOutput() {
        let dist = Distance(yards: 150)
        #expect(dist.formatted(in: .yards) == "150 yd")
        #expect(dist.formatted(in: .meters) == "137 m")
    }
}
