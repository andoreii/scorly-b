import Foundation

/// Mark Broadie's PGA Tour benchmark "expected strokes to hole out"
/// curves, indexed by starting lie and distance.
///
/// Source: `Resources/SGBenchmarks.json`, bundled into the
/// `ScorlyDomain` module. The JSON encodes `expected` as a string so
/// values round-trip exactly through `Decimal` (numeric JSON literals
/// would route through `Double` and introduce binary-float drift).
///
/// Lookup uses linear interpolation between adjacent buckets and clamps
/// to the nearest endpoint outside the table range. The clamp rather
/// than nil-out is deliberate: tour-pro tables go to ~600 yds and
/// ~90 ft, but a v2 user might enter a 700-yd par 5 or a 110-ft putt,
/// and we'd rather give a slightly-off SG number than refuse to
/// compute one.
public struct SGBenchmarkTable: Sendable {
    /// The table loaded from `Resources/SGBenchmarks.json`. Trapped at
    /// process start if the resource is missing or malformed — the JSON
    /// is a build-time invariant of this package.
    public static let bundled: SGBenchmarkTable = {
        do {
            return try loadBundled()
        } catch {
            preconditionFailure(
                "SGBenchmarks.json failed to load — this is a packaging "
                    + "bug in ScorlyDomain. Underlying error: \(error)"
            )
        }
    }()

    /// Returns the expected number of strokes to hole out from `lie` at
    /// `distance`. Distance is in **yards** for every lie except
    /// `.green`, where it's in **feet**.
    ///
    /// Returns `nil` only if the underlying table for `lie` is empty
    /// (impossible with the bundled JSON, but kept for defensive use
    /// with custom-loaded tables in tests).
    public func expectedStrokes(lie: SGBenchmarkLie, distance: Decimal) -> Decimal? {
        guard let series = points[lie], !series.isEmpty else { return nil }
        return interpolate(in: series, at: distance)
    }

    // MARK: - Internals

    private let points: [SGBenchmarkLie: [SGBenchmarkPoint]]

    init(points: [SGBenchmarkLie: [SGBenchmarkPoint]]) {
        // Sort each series by distance so binary-search-like lookup is
        // valid regardless of JSON ordering.
        self.points = points.mapValues { $0.sorted { $0.distance < $1.distance } }
    }

    /// Linear interpolation. `series` is assumed non-empty and sorted by
    /// distance ascending. Out-of-range distances clamp to the nearest
    /// endpoint.
    private func interpolate(in series: [SGBenchmarkPoint], at distance: Decimal) -> Decimal {
        if let first = series.first, distance <= first.distance {
            return first.expected
        }
        if let last = series.last, distance >= last.distance {
            return last.expected
        }
        // Find the bracket [lower, upper] containing `distance`.
        for index in 1..<series.count {
            let upper = series[index]
            if distance <= upper.distance {
                let lower = series[index - 1]
                let span = upper.distance - lower.distance
                guard span > 0 else { return lower.expected }
                let fraction = (distance - lower.distance) / span
                return lower.expected + fraction * (upper.expected - lower.expected)
            }
        }
        // Unreachable given the clamp checks above; return last as a
        // belt-and-braces fallback rather than crash.
        return series[series.count - 1].expected
    }

    // MARK: - Bundled loader

    private static func loadBundled() throws -> Self {
        guard let url = Bundle.module.url(forResource: "SGBenchmarks", withExtension: "json") else {
            throw SGBenchmarkLoadError.resourceMissing
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    /// Decodes a JSON `Data` blob into an `SGBenchmarkTable`. Exposed
    /// internal so tests can verify the round-trip without touching the
    /// bundle.
    static func decode(_ data: Data) throws -> Self {
        let decoded = try JSONDecoder().decode(SGBenchmarkFile.self, from: data)
        var points: [SGBenchmarkLie: [SGBenchmarkPoint]] = [:]
        points[.tee] = decoded.tee
        points[.fairway] = decoded.fairway
        points[.rough] = decoded.rough
        points[.sand] = decoded.sand
        points[.recovery] = decoded.recovery
        points[.green] = decoded.green
        return Self(points: points)
    }
}

/// One (distance, expected-strokes) point in a benchmark curve.
struct SGBenchmarkPoint: Codable, Equatable {
    let distance: Decimal
    /// Expected strokes to hole out. Decoded from a JSON string so the
    /// value is exact (e.g. `"2.92"` → `Decimal(2.92)` exactly, not
    /// `Decimal(Double(2.92))` which is `2.9199999999999...`).
    let expected: Decimal

    private enum CodingKeys: String, CodingKey {
        case distance
        case expected
    }

    init(distance: Decimal, expected: Decimal) {
        self.distance = distance
        self.expected = expected
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        distance = try container.decode(Decimal.self, forKey: .distance)
        let raw = try container.decode(String.self, forKey: .expected)
        guard let parsed = Decimal(string: raw, locale: nil) else {
            throw DecodingError.dataCorruptedError(
                forKey: .expected,
                in: container,
                debugDescription: "Could not parse '\(raw)' as Decimal"
            )
        }
        expected = parsed
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(distance, forKey: .distance)
        // Round-trip-friendly: encode as the same string form we decode
        // from so the on-disk format is stable.
        try container.encode("\(expected)", forKey: .expected)
    }
}

/// JSON file shape — one array per `SGBenchmarkLie`.
private struct SGBenchmarkFile: Decodable {
    let tee: [SGBenchmarkPoint]
    let fairway: [SGBenchmarkPoint]
    let rough: [SGBenchmarkPoint]
    let sand: [SGBenchmarkPoint]
    let recovery: [SGBenchmarkPoint]
    let green: [SGBenchmarkPoint]
}

enum SGBenchmarkLoadError: Error, Equatable {
    case resourceMissing
}
