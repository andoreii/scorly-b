import Foundation

/// Coarse difficulty bucket for a tee within its course.
///
/// Different courses use different tee names ("Blue", "Gold", "Tips",
/// "Members", …) and some carry five or six sets. The Rounds filter needs
/// a small, course-agnostic axis, so tees are grouped by ascending
/// yardage into three buckets: shortest third → `.forward`, middle third
/// → `.middle`, longest third → `.back`.
public enum TeeCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case forward
    case middle
    case back
}
