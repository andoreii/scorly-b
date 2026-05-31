import Foundation

/// One stroke that finished in trouble. Replaces the v1 / v2 pattern
/// of ten separate counter columns (`outOfBoundsLeft`, `hazardLong`,
/// etc.) with a list of typed events. The kind tells you what
/// happened; the direction (optional) tells you where the ball went;
/// the phase (optional for legacy rows) identifies the shot field.
///
/// Stored as a JSON array on the wire (`penalty_events_json` column)
/// and on disk (`LocalHoleStat.penaltyEventsJSON`). HoleStat exposes
/// the old per-field accessors as computed properties over this list
/// so existing call sites (GIR, sand save, effective penalty strokes)
/// keep working.
public struct PenaltyEvent: Sendable, Equatable, Codable {
    public let kind: PenaltyKind
    public let direction: PenaltyDirection?
    /// Shot field that produced the event. Optional for legacy rows
    /// written before phase-aware persistence landed.
    public let phase: PenaltyPhase?

    public init(
        kind: PenaltyKind,
        direction: PenaltyDirection? = nil,
        phase: PenaltyPhase? = nil
    ) {
        self.kind = kind
        self.direction = direction
        self.phase = phase
    }
}

/// What kind of penalty the stroke was. `outOfBounds` = stroke +
/// distance (the ball is unplayable and gone); `hazard` = water or
/// penalty area (the ball is findable, takes a drop).
public enum PenaltyKind: String, Sendable, Equatable, Codable, CaseIterable {
    case outOfBounds
    case hazard
}

/// Where the trouble shot went relative to the target line. `nil`
/// means the user didn't record a direction — legacy rounds where
/// only the count was stored decode this way.
public enum PenaltyDirection: String, Sendable, Equatable, Codable, CaseIterable {
    case left
    case right
    case long
    case short
}

/// Which persisted shot field produced the trouble event. Par-3 input
/// is captured through the approach editor, so it uses `.approach`.
public enum PenaltyPhase: String, Sendable, Equatable, Codable, CaseIterable {
    case tee
    case approach
}
