import Foundation

/// Weather conditions during the round. Multi-select.
///
/// Persisted in `rounds.conditions` as a comma-separated subset of the
/// labels `Sunny, Cloudy, Windy, Rainy`. The CSV ↔ option-set codec
/// lives in `Mappings.swift` (Phase B2); this type defines only the
/// in-memory representation and the canonical label ordering.
public struct Conditions: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sunny = Self(rawValue: 1 << 0)
    public static let cloudy = Self(rawValue: 1 << 1)
    public static let windy = Self(rawValue: 1 << 2)
    public static let rainy = Self(rawValue: 1 << 3)

    /// Stable ordering for serialization. Defines the canonical sequence
    /// flags appear in the DB CSV (e.g. `"Sunny,Windy"`, never `"Windy,Sunny"`).
    public static let labeledFlags: [(label: String, flag: Self)] = [
        (label: "Sunny", flag: .sunny),
        (label: "Cloudy", flag: .cloudy),
        (label: "Windy", flag: .windy),
        (label: "Rainy", flag: .rainy),
    ]
}
