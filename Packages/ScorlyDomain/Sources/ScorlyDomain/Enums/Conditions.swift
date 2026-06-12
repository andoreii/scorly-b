import Foundation

/// Weather conditions during the round. Multi-select; persisted as a
/// comma-separated subset of labels (see Mappings.swift for the CSV codec).
public struct Conditions: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sunny = Self(rawValue: 1 << 0)
    public static let cloudy = Self(rawValue: 1 << 1)
    public static let windy = Self(rawValue: 1 << 2)
    public static let rainy = Self(rawValue: 1 << 3)

    /// Canonical ordering for CSV serialization.
    public static let labeledFlags: [(label: String, flag: Self)] = [
        (label: "Sunny", flag: .sunny),
        (label: "Cloudy", flag: .cloudy),
        (label: "Windy", flag: .windy),
        (label: "Rainy", flag: .rainy),
    ]
}
