import Foundation

/// One stroke that finished in trouble. Stored as a JSON array (`penalty_events_json`);
/// `HoleStat` exposes the old per-field accessors as computed properties over this list.
public struct PenaltyEvent: Sendable, Equatable, Codable {
    public let kind: PenaltyKind
    public let direction: PenaltyDirection?
    /// Optional for legacy rows written before phase-aware persistence landed.
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

/// `outOfBounds` = stroke and distance (ball unplayable, gone); `hazard` = water or
/// penalty area (ball findable, takes a drop).
public enum PenaltyKind: String, Sendable, Equatable, Codable, CaseIterable {
    case outOfBounds
    case hazard
}

/// Where the trouble shot went relative to the target line. `nil` means no direction
/// recorded (legacy rounds that only stored a count).
public enum PenaltyDirection: String, Sendable, Equatable, Codable, CaseIterable {
    case left
    case right
    case long
    case short
}

/// Which persisted shot field produced the event. Par-3 input goes through
/// the approach editor, so it uses `.approach`.
public enum PenaltyPhase: String, Sendable, Equatable, Codable, CaseIterable {
    case tee
    case approach
}
