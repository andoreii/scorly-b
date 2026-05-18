import Foundation
import Testing
@testable import ScorlyDomain

struct SGBenchmarkTableTests {
    // MARK: - Bundled load

    @Test("Bundled JSON loads for every benchmark lie")
    func bundledLoadsForEveryLie() {
        let table = SGBenchmarkTable.bundled
        for lie in SGBenchmarkLie.allCases {
            let probe: Decimal = (lie == .green) ? 5 : 100
            #expect(
                table.expectedStrokes(lie: lie, distance: probe) != nil,
                "Missing benchmark series for \(lie)"
            )
        }
    }

    @Test("Bundled values match Broadie spot-checks (no Double drift)")
    func bundledExactSpotChecks() {
        let table = SGBenchmarkTable.bundled
        // Each value here is the published Broadie figure; if these
        // don't match exactly, the JSON-string-→-Decimal round-trip
        // is silently routing through Double.
        #expect(table.expectedStrokes(lie: .fairway, distance: 100) == dec("2.80"))
        #expect(table.expectedStrokes(lie: .rough, distance: 200) == dec("3.42"))
        #expect(table.expectedStrokes(lie: .sand, distance: 50) == dec("2.92"))
        #expect(table.expectedStrokes(lie: .recovery, distance: 100) == dec("3.81"))
        #expect(table.expectedStrokes(lie: .tee, distance: 400) == dec("3.99"))
        #expect(table.expectedStrokes(lie: .green, distance: 8) == dec("1.50"))
    }

    // MARK: - Interpolation

    @Test("Linear interpolation between adjacent buckets")
    func interpolatesBetweenBuckets() {
        let table = SGBenchmarkTable.bundled
        // Fairway: 100 yds = 2.80, 120 yds = 2.85 → midpoint at 110 = 2.825
        #expect(table.expectedStrokes(lie: .fairway, distance: 110) == dec("2.825"))
        // Green: 8 ft = 1.50, 9 ft = 1.56 → 8.5 ft = 1.53
        #expect(table.expectedStrokes(lie: .green, distance: dec("8.5")) == dec("1.53"))
    }

    @Test("Below-range distance clamps to first bucket")
    func clampsBelowRange() {
        let table = SGBenchmarkTable.bundled
        // Fairway series starts at 10 yds; anything ≤ 10 returns 2.18.
        #expect(table.expectedStrokes(lie: .fairway, distance: 5) == dec("2.18"))
        #expect(table.expectedStrokes(lie: .fairway, distance: 0) == dec("2.18"))
        // Green starts at 3 ft; 1 ft, 2 ft both clamp to 1.04.
        #expect(table.expectedStrokes(lie: .green, distance: 1) == dec("1.04"))
    }

    @Test("Above-range distance clamps to last bucket")
    func clampsAboveRange() {
        let table = SGBenchmarkTable.bundled
        // Tee series ends at 600 yds; longer holes still get a value.
        #expect(table.expectedStrokes(lie: .tee, distance: 700) == dec("4.82"))
        // Fairway series ends at 400 yds.
        #expect(table.expectedStrokes(lie: .fairway, distance: 500) == dec("3.97"))
    }

    @Test("Exact bucket distances return their bucket value")
    func exactBucketLookup() {
        let table = SGBenchmarkTable.bundled
        #expect(table.expectedStrokes(lie: .fairway, distance: 200) == dec("3.19"))
        #expect(table.expectedStrokes(lie: .green, distance: 30) == dec("1.98"))
    }

    // MARK: - Decoding

    @Test("Custom-decoded table parses Decimal strings exactly")
    func customDecodeRoundTrips() throws {
        let json = """
        {
            "tee":      [{ "distance": 100, "expected": "2.50" }],
            "fairway":  [{ "distance": 100, "expected": "2.75" }],
            "rough":    [{ "distance": 100, "expected": "3.00" }],
            "sand":     [{ "distance": 100, "expected": "3.10" }],
            "recovery": [{ "distance": 100, "expected": "3.80" }],
            "green":    [{ "distance": 10,  "expected": "1.61" }]
        }
        """
        let table = try SGBenchmarkTable.decode(Data(json.utf8))
        #expect(table.expectedStrokes(lie: .fairway, distance: 100) == dec("2.75"))
        #expect(table.expectedStrokes(lie: .green, distance: 10) == dec("1.61"))
    }

    @Test("Malformed expected string throws")
    func malformedExpectedThrows() {
        let json = """
        {
            "tee": [], "fairway": [{"distance": 100, "expected": "abc"}],
            "rough": [], "sand": [], "recovery": [], "green": []
        }
        """
        #expect(throws: DecodingError.self) {
            _ = try SGBenchmarkTable.decode(Data(json.utf8))
        }
    }

    @Test("Empty series returns nil rather than crashing")
    func emptySeriesReturnsNil() throws {
        let json = """
        {
            "tee": [], "fairway": [], "rough": [],
            "sand": [], "recovery": [], "green": []
        }
        """
        let table = try SGBenchmarkTable.decode(Data(json.utf8))
        #expect(table.expectedStrokes(lie: .fairway, distance: 100) == nil)
    }

    // MARK: - Helper

    private func dec(_ value: String) -> Decimal {
        Decimal(string: value, locale: nil) ?? .nan
    }
}
