import Foundation

/// Persisted shape of a finished round, with the richer write-side metadata
/// that `CompletedRound` (the read shape) doesn't carry.
public struct RoundDraft: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let externalId: UUID
    public let userId: UUID
    public let courseId: UUID
    public let teeId: UUID?
    public let datePlayed: Date
    public let holesPlayed: HolesPlayed
    public let roundType: RoundType?
    public let roundFormat: RoundFormat?
    public let conditions: Conditions
    public let temperature: Int?
    public let walkingVsRiding: WalkingVsRiding?
    public let startedAt: Date?
    public let finishedAt: Date?
    public let mentalState: Int?
    public let notes: String?
    public let totalScore: Int
    public let whsDifferential: Decimal?
    public let createdAt: Date
    public let holeStats: [HoleStat]
    public let players: [RoundPlayer]

    public init(
        id: UUID,
        externalId: UUID,
        userId: UUID,
        courseId: UUID,
        teeId: UUID? = nil,
        datePlayed: Date,
        holesPlayed: HolesPlayed,
        roundType: RoundType? = nil,
        roundFormat: RoundFormat? = nil,
        conditions: Conditions = [],
        temperature: Int? = nil,
        walkingVsRiding: WalkingVsRiding? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        mentalState: Int? = nil,
        notes: String? = nil,
        totalScore: Int,
        whsDifferential: Decimal? = nil,
        createdAt: Date,
        holeStats: [HoleStat] = [],
        players: [RoundPlayer] = []
    ) {
        self.id = id
        self.externalId = externalId
        self.userId = userId
        self.courseId = courseId
        self.teeId = teeId
        self.datePlayed = datePlayed
        self.holesPlayed = holesPlayed
        self.roundType = roundType
        self.roundFormat = roundFormat
        self.conditions = conditions
        self.temperature = temperature
        self.walkingVsRiding = walkingVsRiding
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.mentalState = mentalState
        self.notes = notes
        self.totalScore = totalScore
        self.whsDifferential = whsDifferential
        self.createdAt = createdAt
        self.holeStats = holeStats
        self.players = players
    }
}
