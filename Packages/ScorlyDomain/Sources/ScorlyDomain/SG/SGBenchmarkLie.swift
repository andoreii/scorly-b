import Foundation

/// The 6 starting positions Broadie's expected-strokes tables are keyed by.
/// Mapping from `Lie` lives on `SGCalculator`.
public enum SGBenchmarkLie: String, Codable, CaseIterable, Sendable {
    /// Par 4 / par 5 tee shot. Par-3 tee shots use `.fairway` by convention.
    case tee
    case fairway
    case rough
    case sand
    case recovery
    /// Distance is in **feet**, not yards.
    case green
}
