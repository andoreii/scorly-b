import Foundation

/// The four shot categories Strokes Gained aggregates over.
///
/// Categorisation is decided at reconstruction time per shot:
/// - `.ott` — first stroke on a par 4 or par 5 (tee shot).
/// - `.app` — par-3 tee shot, OR the second stroke on a par 4 / par 5
///   (the approach to the green).
/// - `.arg` — any non-putt stroke after the approach (chips, pitches,
///   bunker shots near the green).
/// - `.putt` — any stroke taken from the green.
public enum SGCategory: String, Codable, CaseIterable, Sendable {
    case ott
    case app
    case arg
    case putt
}
