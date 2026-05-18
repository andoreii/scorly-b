import Foundation

/// Where the pin sat on the green for a given hole.
/// Persisted in `hole_stats.pin_position`.
public enum PinPosition: String, Codable, CaseIterable, Hashable, Sendable {
    case front = "Front"
    case middle = "Middle"
    case back = "Back"
}
