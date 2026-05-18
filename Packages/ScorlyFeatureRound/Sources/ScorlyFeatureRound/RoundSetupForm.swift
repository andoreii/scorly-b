import Foundation
import ScorlyDomain

/// Mutable presentation-layer model for the Round Setup screen. The
/// form is the source of truth while the user is filling it in;
/// `RoundDraft` is built from this only at the end of the round
/// (after Play / Confirm).
///
/// `courseId` and `teeId` are optional during setup — the form
/// gates the "Tee off" button on whether enough is filled in via
/// `isReady`.
public struct RoundSetupForm: Sendable, Equatable {
    public var courseId: UUID?
    public var teeId: UUID?
    public var holesPlayed: HolesPlayed
    public var datePlayed: Date
    public var roundType: RoundType?
    public var roundFormat: RoundFormat?
    public var conditions: Conditions
    public var temperature: Int
    public var walkingVsRiding: WalkingVsRiding?
    public var mentalState: Int
    public var notes: String
    public var players: [Player]

    public struct Player: Sendable, Equatable, Identifiable {
        public let id: UUID
        public var name: String
        public var handicap: Decimal

        public init(id: UUID = UUID(), name: String, handicap: Decimal) {
            self.id = id
            self.name = name
            self.handicap = handicap
        }
    }

    public init(
        courseId: UUID? = nil,
        teeId: UUID? = nil,
        holesPlayed: HolesPlayed = .eighteen,
        datePlayed: Date = Date(),
        roundType: RoundType? = .casual,
        roundFormat: RoundFormat? = .stroke,
        conditions: Conditions = [.sunny],
        temperature: Int = 17,
        walkingVsRiding: WalkingVsRiding? = .walking,
        mentalState: Int = 7,
        notes: String = "",
        players: [Player] = [Player(name: "You", handicap: 12.4)]
    ) {
        self.courseId = courseId
        self.teeId = teeId
        self.holesPlayed = holesPlayed
        self.datePlayed = datePlayed
        self.roundType = roundType
        self.roundFormat = roundFormat
        self.conditions = conditions
        self.temperature = temperature
        self.walkingVsRiding = walkingVsRiding
        self.mentalState = mentalState
        self.notes = notes
        self.players = players
    }

    /// True once a course + tee are chosen. Other fields have sensible
    /// defaults, so the rest of the form is optional polish.
    public var isReady: Bool {
        courseId != nil && teeId != nil
    }
}
