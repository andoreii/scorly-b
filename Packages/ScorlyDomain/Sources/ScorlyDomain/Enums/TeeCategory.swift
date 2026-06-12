import Foundation

/// Coarse difficulty bucket for a tee within its course, grouped by
/// ascending yardage into thirds, so the Rounds filter has a course-agnostic axis.
public enum TeeCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case forward
    case middle
    case back
}
