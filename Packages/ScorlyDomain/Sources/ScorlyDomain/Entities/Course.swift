import Foundation

/// A user's golf course definition.
///
/// `externalId` is the client-generated UUID that becomes
/// `courses.course_external_id` on the server — the idempotency key the
/// SyncEngine uses to deduplicate retried writes (plan invariant 6).
///
/// A Course owns its tees and holes; persisting a Course persists the whole
/// graph. The `colorTheme` string is stored verbatim in the DB and parsed by
/// the UI per the v1 encoding (`name | CustomSolid:RRGGBB | CustomGradient:RRGGBB-RRGGBB`).
public struct Course: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let externalId: UUID
    public let userId: UUID
    public let name: String
    public let location: String?
    public let notes: String?
    public let colorTheme: String?
    public let createdAt: Date
    public let roundsPlayed: Int
    public let averageScore: Int?
    public let bestScore: Int?
    public let tees: [Tee]
    public let holes: [Hole]

    public init(
        id: UUID,
        externalId: UUID,
        userId: UUID,
        name: String,
        location: String? = nil,
        notes: String? = nil,
        colorTheme: String? = nil,
        createdAt: Date,
        roundsPlayed: Int = 0,
        averageScore: Int? = nil,
        bestScore: Int? = nil,
        tees: [Tee] = [],
        holes: [Hole] = []
    ) {
        self.id = id
        self.externalId = externalId
        self.userId = userId
        self.name = name
        self.location = location
        self.notes = notes
        self.colorTheme = colorTheme
        self.createdAt = createdAt
        self.roundsPlayed = roundsPlayed
        self.averageScore = averageScore
        self.bestScore = bestScore
        self.tees = tees
        self.holes = holes
    }
}

/// A set of tees for a course (e.g. "Championship", "Members"). Carries the
/// per-tee yardages on each hole via `teeHoles`.
public struct Tee: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let externalId: UUID
    public let name: String
    public let courseRating: Decimal?
    public let slopeRating: Decimal?
    public let totalYardage: Int?
    public let teeHoles: [TeeHole]

    public init(
        id: UUID,
        externalId: UUID,
        name: String,
        courseRating: Decimal? = nil,
        slopeRating: Decimal? = nil,
        totalYardage: Int? = nil,
        teeHoles: [TeeHole] = []
    ) {
        self.id = id
        self.externalId = externalId
        self.name = name
        self.courseRating = courseRating
        self.slopeRating = slopeRating
        self.totalYardage = totalYardage
        self.teeHoles = teeHoles
    }
}

/// A hole on a course — par + (optional) stroke index. Per-tee yardage lives
/// on `TeeHole`, not here.
public struct Hole: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let externalId: UUID
    public let number: Int
    public let par: Int
    public let handicapIndex: Int?

    public init(id: UUID, externalId: UUID, number: Int, par: Int, handicapIndex: Int? = nil) {
        self.id = id
        self.externalId = externalId
        self.number = number
        self.par = par
        self.handicapIndex = handicapIndex
    }
}

/// Yardage for one hole from one tee. Lives under `Tee` because each tee has
/// 18 of these.
public struct TeeHole: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let externalId: UUID
    public let holeNumber: Int
    public let yardage: Int

    public init(id: UUID, externalId: UUID, holeNumber: Int, yardage: Int) {
        self.id = id
        self.externalId = externalId
        self.holeNumber = holeNumber
        self.yardage = yardage
    }
}
