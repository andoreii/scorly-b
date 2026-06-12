import Foundation

/// Mark Broadie's PGA Tour benchmark "expected strokes to hole out"
/// curves, indexed by starting lie and distance. Loaded from
/// `Resources/SGBenchmarks.json`. Lookup interpolates between adjacent
/// buckets and clamps to the nearest endpoint outside the table range.
public struct SGBenchmarkTable: Sendable {
    /// Trapped at process start if the resource is missing or malformed.
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

    /// Distance is yards, except feet for `.green`. `nil` only if the table for `lie` is empty.
    public func expectedStrokes(lie: SGBenchmarkLie, distance: Decimal) -> Decimal? {
        guard let series = points[lie], !series.isEmpty else { return nil }
        return interpolate(in: series, at: distance)
    }

    // MARK: - Internals

    private let points: [SGBenchmarkLie: [SGBenchmarkPoint]]

    init(points: [SGBenchmarkLie: [SGBenchmarkPoint]]) {
        // Sort by distance regardless of JSON ordering.
        self.points = points.mapValues { $0.sorted { $0.distance < $1.distance } }
    }

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
        // Unreachable given the clamps above; fallback rather than crash.
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
    /// Decoded from a JSON string so values like "2.92" stay exact (avoids Double drift).
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
        // Encode in the same string form we decode, so the on-disk format is stable.
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
