import Foundation

/// User's preferred unit for displaying distances.
///
/// Persisted to `UserDefaults` under `com.scorly.distanceUnit` (raw value).
/// Storage in the DB and SwiftData is always canonical yards regardless;
/// this type only governs presentation.
public enum DistanceUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case yards
    case meters

    /// Short symbol for inline display (`yd`, `m`).
    public var symbol: String {
        switch self {
        case .yards: "yd"
        case .meters: "m"
        }
    }
}
