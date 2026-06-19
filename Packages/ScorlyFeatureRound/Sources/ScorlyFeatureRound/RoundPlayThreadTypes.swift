import Foundation

/// Tri-state hit indicator for the Hole Summary cells. Avoids an optional
/// `Bool` (hit / miss / not-yet-known / not-applicable) so the meaning is
/// explicit at the call site.
public enum HitState: Equatable, Sendable {
    case hit
    case miss
    case unknown
    case notApplicable

    static func from(_ value: Bool) -> Self {
        value ? .hit : .miss
    }
}

/// Live values rendered by `HoleSummaryCard`. A plain value type (rather
/// than a tuple) so it reads clearly and satisfies the lint budget.
public struct HoleSummaryStats: Equatable, Sendable {
    public let score: Int?
    public let fir: HitState
    public let gir: HitState
    public let putts: Int
    public let pen: Int

    public init(score: Int?, fir: HitState, gir: HitState, putts: Int, pen: Int) {
        self.score = score
        self.fir = fir
        self.gir = gir
        self.putts = putts
        self.pen = pen
    }
}

/// Hazard shortcut tags surfaced on the shot sheet for full shots / chips.
public enum HazardTag: String, CaseIterable, Sendable {
    case bunker = "Bunker"
    case ob = "OB"
    case water = "Water"
    case unplayable = "Unplayable"
}

extension Array {
    /// Bounds-checked access — returns nil instead of trapping.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
