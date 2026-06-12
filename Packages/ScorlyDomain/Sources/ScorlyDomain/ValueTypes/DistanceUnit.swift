import Foundation

/// User's preferred unit for displaying distances. Storage is always
/// canonical yards; this only governs presentation.
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
