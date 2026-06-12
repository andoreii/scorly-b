import Foundation

/// The four shot categories Strokes Gained aggregates over: tee shot
/// (par 4/5), approach, around the green, and putts.
public enum SGCategory: String, Codable, CaseIterable, Sendable {
    case ott
    case app
    case arg
    case putt
}
