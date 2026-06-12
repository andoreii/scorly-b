import Foundation

/// A length measurement with yards as the canonical storage unit. Display
/// converts to the user's `DistanceUnit` preference. Negative distances
/// are clamped to zero.
public struct Distance: Hashable, Codable, Sendable, Comparable {
    /// Canonical storage — always yards.
    public let yards: Int

    public init(yards: Int) {
        self.yards = max(0, yards)
    }

    /// Construct from a value in the given unit. Rounds to the nearest yard.
    public init(_ value: Double, unit: DistanceUnit) {
        switch unit {
        case .yards:
            self.init(yards: Int(value.rounded()))
        case .meters:
            self.init(yards: Int((value / Self.metersPerYard).rounded()))
        }
    }

    /// Distance expressed in meters.
    public var meters: Double {
        Double(yards) * Self.metersPerYard
    }

    /// Returns the magnitude in the requested unit, rounded to a whole number.
    public func value(in unit: DistanceUnit) -> Int {
        switch unit {
        case .yards: yards
        case .meters: Int(meters.rounded())
        }
    }

    /// "<n> <symbol>" suitable for inline display. Not localized.
    public func formatted(in unit: DistanceUnit) -> String {
        "\(value(in: unit)) \(unit.symbol)"
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.yards < rhs.yards
    }

    /// 1 yard = 0.9144 meters (exact, by international yard definition).
    public static let metersPerYard = 0.9144
}
