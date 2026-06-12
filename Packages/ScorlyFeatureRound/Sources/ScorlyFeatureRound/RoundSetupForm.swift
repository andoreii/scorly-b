import Foundation
import ScorlyDomain

/// Mutable presentation-layer model for the Round Setup screen. Source of
/// truth while filling in the form; `RoundDraft` is built from this at the
/// end of the round. `courseId` / `teeId` are optional until `isReady`.
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
        /// `nil` means "no handicap entered" (for "You", the WHS index once enough rounds qualify).
        public var handicap: Decimal?

        public init(id: UUID = UUID(), name: String, handicap: Decimal? = nil) {
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
        players: [Player] = [Player(name: "You", handicap: nil)]
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
