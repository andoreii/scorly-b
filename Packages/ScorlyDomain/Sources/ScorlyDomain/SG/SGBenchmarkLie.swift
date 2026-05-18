import Foundation

/// The 6 starting positions Broadie's expected-strokes tables are keyed by.
///
/// Distinct from `Lie`: `SGBenchmarkLie` includes `.tee` (the conceptual
/// teeing-ground starting position for par 4 / par 5, not a value any
/// shot can *land* in) and collapses the v2 directional `Lie` cases into
/// the 5 published Broadie categories.
///
/// `Lie → SGBenchmarkLie` mapping lives on `SGCalculator` to keep this
/// type a pure data tag.
public enum SGBenchmarkLie: String, Codable, CaseIterable, Sendable {
    /// Par 4 / par 5 tee shot. Par-3 tee shots use `.fairway` by
    /// convention (Broadie's original analysis treats them as approach
    /// shots; the resulting baseline is well-defined for the typical
    /// par-3 distance range).
    case tee
    case fairway
    case rough
    case sand
    case recovery
    /// Distance is in **feet**, not yards.
    case green
}
