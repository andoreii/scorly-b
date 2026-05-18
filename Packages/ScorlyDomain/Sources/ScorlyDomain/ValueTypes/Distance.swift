import Foundation

/// A length measurement with yards as the canonical storage unit.
///
/// Storage in the DB and SwiftData is always whole yards. Display uses
/// the user's `DistanceUnit` preference, converting on the fly. Negative
/// distances are clamped to zero — there's no such thing as a negative
/// shot distance in the domain.
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

    /// "<n> <symbol>" suitable for inline display. Not localized — number
    /// localization is handled in Phase F (i18n + accessibility scaffolding).
    public func formatted(in unit: DistanceUnit) -> String {
        "\(value(in: unit)) \(unit.symbol)"
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.yards < rhs.yards
    }

    /// 1 yard = 0.9144 meters (exact, by international yard definition).
    public static let metersPerYard = 0.9144
}
