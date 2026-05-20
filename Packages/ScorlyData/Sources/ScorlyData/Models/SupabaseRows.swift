// Optional Bools are deliberate: derived per-hole stats (GIR, 3-putt,
// up-and-down, sand save, opportunity flags) carry a "not applicable"
// state that a non-optional Bool can't express. Disabling the lint here
// is the right tradeoff. Snake-case keys live on the wire, not on these
// types — the JSON coder bridges them.
// swiftlint:disable discouraged_optional_boolean

import Foundation
import ScorlyDomain

// Codable Row / Insert / Update types mirroring the Supabase schema.
//
// Naming convention (ported from v1 DataService.swift):
// - *Row is the read shape — every column nullable as the DB allows.
// - *Insert is the write shape used on from(table).insert(payload).
// - *Update is the partial-write shape — every field optional so a
//   selective update() only touches the columns the caller passes.
//
// All types use camelCase property names and rely on the snake-case
// JSON coder (SupabaseConfig.encoder / decoder) to bridge to/from the
// course_id / date_played style on the wire.

// MARK: - users

public struct UserRow: Sendable, Codable, Equatable {
    public let id: UUID
    public let handicapIndex: Decimal?
    public let createdAt: Date
}

public struct UserInsert: Sendable, Codable, Equatable {
    public let id: UUID
    public let handicapIndex: Decimal?

    public init(id: UUID, handicapIndex: Decimal? = nil) {
        self.id = id
        self.handicapIndex = handicapIndex
    }
}

public struct UserUpdate: Sendable, Codable, Equatable {
    public let handicapIndex: Decimal?

    public init(handicapIndex: Decimal? = nil) {
        self.handicapIndex = handicapIndex
    }
}

// MARK: - courses

public struct CourseRow: Sendable, Codable, Equatable {
    public let courseId: Int
    public let userId: UUID
    public let courseName: String
    public let location: String?
    public let notes: String?
    public let colorTheme: String?
    public let courseExternalId: String?
    public let createdAt: Date
    public let tees: [TeeRow]?
    public let holes: [HoleRow]?
}

public struct CourseInsert: Sendable, Codable, Equatable {
    public let userId: UUID
    public let courseName: String
    public let location: String?
    public let notes: String?
    public let colorTheme: String?
    public let courseExternalId: String

    public init(
        userId: UUID,
        courseName: String,
        location: String? = nil,
        notes: String? = nil,
        colorTheme: String? = nil,
        courseExternalId: String
    ) {
        self.userId = userId
        self.courseName = courseName
        self.location = location
        self.notes = notes
        self.colorTheme = colorTheme
        self.courseExternalId = courseExternalId
    }
}

public struct CourseUpdate: Sendable, Codable, Equatable {
    public let courseName: String?
    public let location: String?
    public let notes: String?
    public let colorTheme: String?

    public init(
        courseName: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        colorTheme: String? = nil
    ) {
        self.courseName = courseName
        self.location = location
        self.notes = notes
        self.colorTheme = colorTheme
    }
}

// MARK: - tees

public struct TeeRow: Sendable, Codable, Equatable {
    public let teeId: Int
    public let courseId: Int
    public let teeName: String
    public let courseRating: Decimal?
    public let slopeRating: Decimal?
    public let yardage: Int?
    public let teeExternalId: String?
    public let teeHoles: [TeeHoleRow]?
}

public struct TeeInsert: Sendable, Codable, Equatable {
    public let courseId: Int
    public let teeName: String
    public let courseRating: Decimal?
    public let slopeRating: Decimal?
    public let yardage: Int?
    public let teeExternalId: String

    public init(
        courseId: Int,
        teeName: String,
        courseRating: Decimal? = nil,
        slopeRating: Decimal? = nil,
        yardage: Int? = nil,
        teeExternalId: String
    ) {
        self.courseId = courseId
        self.teeName = teeName
        self.courseRating = courseRating
        self.slopeRating = slopeRating
        self.yardage = yardage
        self.teeExternalId = teeExternalId
    }
}

// MARK: - holes

public struct HoleRow: Sendable, Codable, Equatable {
    public let holeId: Int
    public let courseId: Int
    public let holeNumber: Int
    public let par: Int
    public let holeHandicapIndex: Int?
    public let holeExternalId: String?
}

public struct HoleInsert: Sendable, Codable, Equatable {
    public let courseId: Int
    public let holeNumber: Int
    public let par: Int
    public let holeHandicapIndex: Int?
    public let holeExternalId: String

    public init(
        courseId: Int,
        holeNumber: Int,
        par: Int,
        holeHandicapIndex: Int? = nil,
        holeExternalId: String
    ) {
        self.courseId = courseId
        self.holeNumber = holeNumber
        self.par = par
        self.holeHandicapIndex = holeHandicapIndex
        self.holeExternalId = holeExternalId
    }
}

// MARK: - tee_holes

public struct TeeHoleRow: Sendable, Codable, Equatable {
    public let teeHoleId: Int
    public let teeId: Int
    public let holeNumber: Int
    public let yardage: Int
    public let teeHoleExternalId: String?
}

public struct TeeHoleInsert: Sendable, Codable, Equatable {
    public let teeId: Int
    public let holeNumber: Int
    public let yardage: Int
    public let teeHoleExternalId: String

    public init(teeId: Int, holeNumber: Int, yardage: Int, teeHoleExternalId: String) {
        self.teeId = teeId
        self.holeNumber = holeNumber
        self.yardage = yardage
        self.teeHoleExternalId = teeHoleExternalId
    }
}

// MARK: - rounds

public struct RoundRow: Sendable, Codable, Equatable {
    public let roundId: Int
    public let userId: UUID
    public let courseId: Int
    public let teeId: Int?
    public let datePlayed: Date
    public let holesPlayed: String
    public let roundType: String?
    public let roundFormat: String?
    public let conditions: String?
    public let temperature: Int?
    public let walkingVsRiding: String?
    public let startedAt: Date?
    public let finishedAt: Date?
    public let mentalState: Int?
    public let roundExternalId: String?
    public let notes: String?
    public let whsDifferential: Decimal?
    public let totalScore: Int?
    public let createdAt: Date
    public let holeStats: [HoleStatRow]?
    public let players: [RoundPlayer]?
}

public struct RoundInsert: Sendable, Codable, Equatable {
    public let userId: UUID
    public let courseId: Int
    public let teeId: Int?
    public let datePlayed: String
    public let holesPlayed: String
    public let roundType: String?
    public let roundFormat: String?
    public let conditions: String?
    public let temperature: Int?
    public let walkingVsRiding: String?
    public let startedAt: Date?
    public let finishedAt: Date?
    public let mentalState: Int?
    public let roundExternalId: String
    public let notes: String?
    public let whsDifferential: Decimal?
    public let totalScore: Int?
    public let players: [RoundPlayer]

    public init(
        userId: UUID,
        courseId: Int,
        teeId: Int? = nil,
        datePlayed: String,
        holesPlayed: String,
        roundType: String? = nil,
        roundFormat: String? = nil,
        conditions: String? = nil,
        temperature: Int? = nil,
        walkingVsRiding: String? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        mentalState: Int? = nil,
        roundExternalId: String,
        notes: String? = nil,
        whsDifferential: Decimal? = nil,
        totalScore: Int? = nil,
        players: [RoundPlayer] = []
    ) {
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
        self.roundExternalId = roundExternalId
        self.notes = notes
        self.whsDifferential = whsDifferential
        self.totalScore = totalScore
        self.players = players
    }
}

/// Outbox payload for `rounds.insert`. Carries external IDs for course/tee
/// (resolved to server serial IDs at push time, after the local cache has
/// picked up the latest pull) plus the round's hole stats so a single
/// outbox entry fans out to two Supabase inserts.
///
/// We don't enqueue per-hole `holeStat` entries — the parent round's
/// server ID isn't known until the round insert returns, so the push
/// handler does the chained insert atomically.
public struct RoundOutboxBody: Sendable, Codable, Equatable {
    public let courseExternalId: UUID
    public let teeExternalId: UUID?
    public let userId: UUID
    public let datePlayed: String
    public let holesPlayed: String
    public let roundType: String?
    public let roundFormat: String?
    public let conditions: String?
    public let temperature: Int?
    public let walkingVsRiding: String?
    public let startedAt: Date?
    public let finishedAt: Date?
    public let mentalState: Int?
    public let roundExternalId: String
    public let notes: String?
    public let whsDifferential: Decimal?
    public let totalScore: Int?
    public let players: [RoundPlayer]
    public let holeStats: [PendingHoleStat]

    public struct PendingHoleStat: Sendable, Codable, Equatable {
        public let holeStatExternalId: String
        public let holeNumber: Int
        public let strokes: Int
        public let putts: Int
        public let teeShot: String?
        public let approach: String?
        public let outOfBoundsCount: Int
        public let penaltyStrokes: Int
        public let hazardCount: Int
        public let upAndDownSuccess: Bool?
        public let sandSaveSuccess: Bool?

        public init(
            holeStatExternalId: String,
            holeNumber: Int,
            strokes: Int,
            putts: Int,
            teeShot: String? = nil,
            approach: String? = nil,
            outOfBoundsCount: Int = 0,
            penaltyStrokes: Int = 0,
            hazardCount: Int = 0,
            upAndDownSuccess: Bool? = nil,
            sandSaveSuccess: Bool? = nil
        ) {
            self.holeStatExternalId = holeStatExternalId
            self.holeNumber = holeNumber
            self.strokes = strokes
            self.putts = putts
            self.teeShot = teeShot
            self.approach = approach
            self.outOfBoundsCount = outOfBoundsCount
            self.penaltyStrokes = penaltyStrokes
            self.hazardCount = hazardCount
            self.upAndDownSuccess = upAndDownSuccess
            self.sandSaveSuccess = sandSaveSuccess
        }
    }

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        courseExternalId: UUID,
        teeExternalId: UUID? = nil,
        userId: UUID,
        datePlayed: String,
        holesPlayed: String,
        roundType: String? = nil,
        roundFormat: String? = nil,
        conditions: String? = nil,
        temperature: Int? = nil,
        walkingVsRiding: String? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        mentalState: Int? = nil,
        roundExternalId: String,
        notes: String? = nil,
        whsDifferential: Decimal? = nil,
        totalScore: Int? = nil,
        players: [RoundPlayer] = [],
        holeStats: [PendingHoleStat] = []
    ) {
        self.courseExternalId = courseExternalId
        self.teeExternalId = teeExternalId
        self.userId = userId
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
        self.roundExternalId = roundExternalId
        self.notes = notes
        self.whsDifferential = whsDifferential
        self.totalScore = totalScore
        self.players = players
        self.holeStats = holeStats
    }
}

// MARK: - hole_stats

public struct HoleStatRow: Sendable, Codable, Equatable {
    public let holeStatId: Int
    public let roundId: Int
    public let holeNumber: Int
    public let strokes: Int
    public let putts: Int
    public let teeShot: String?
    public let approach: String?
    public let teeClub: String?
    public let approachClub: String?
    public let outOfBoundsCount: Int?
    public let penaltyStrokes: Int?
    public let hazardCount: Int?
    public let greenInReg: Bool?
    public let threePutt: Bool?
    public let girOpportunity: Bool?
    public let fairwayOpportunity: Bool?
    public let upAndDownSuccess: Bool?
    public let sandSaveSuccess: Bool?
    public let puttDistances: [Int]?
    public let teeShotDistance: Int?
    public let approachDistance: Int?
    public let pinPosition: String?
    public let holeStatExternalId: String?
    public let createdAt: Date
}

public struct HoleStatInsert: Sendable, Codable, Equatable {
    public let roundId: Int
    public let holeNumber: Int
    public let strokes: Int
    public let putts: Int
    public let teeShot: String?
    public let approach: String?
    public let teeClub: String?
    public let approachClub: String?
    public let outOfBoundsCount: Int
    public let penaltyStrokes: Int
    public let hazardCount: Int
    public let greenInReg: Bool?
    public let threePutt: Bool?
    public let girOpportunity: Bool?
    public let fairwayOpportunity: Bool?
    public let upAndDownSuccess: Bool?
    public let sandSaveSuccess: Bool?
    public let puttDistances: [Int]?
    public let teeShotDistance: Int?
    public let approachDistance: Int?
    public let pinPosition: String?
    public let holeStatExternalId: String

    public init(
        roundId: Int,
        holeNumber: Int,
        strokes: Int,
        putts: Int,
        teeShot: String? = nil,
        approach: String? = nil,
        teeClub: String? = nil,
        approachClub: String? = nil,
        outOfBoundsCount: Int = 0,
        penaltyStrokes: Int = 0,
        hazardCount: Int = 0,
        greenInReg: Bool? = nil,
        threePutt: Bool? = nil,
        girOpportunity: Bool? = nil,
        fairwayOpportunity: Bool? = nil,
        upAndDownSuccess: Bool? = nil,
        sandSaveSuccess: Bool? = nil,
        puttDistances: [Int]? = nil,
        teeShotDistance: Int? = nil,
        approachDistance: Int? = nil,
        pinPosition: String? = nil,
        holeStatExternalId: String
    ) {
        self.roundId = roundId
        self.holeNumber = holeNumber
        self.strokes = strokes
        self.putts = putts
        self.teeShot = teeShot
        self.approach = approach
        self.teeClub = teeClub
        self.approachClub = approachClub
        self.outOfBoundsCount = outOfBoundsCount
        self.penaltyStrokes = penaltyStrokes
        self.hazardCount = hazardCount
        self.greenInReg = greenInReg
        self.threePutt = threePutt
        self.girOpportunity = girOpportunity
        self.fairwayOpportunity = fairwayOpportunity
        self.upAndDownSuccess = upAndDownSuccess
        self.sandSaveSuccess = sandSaveSuccess
        self.puttDistances = puttDistances
        self.teeShotDistance = teeShotDistance
        self.approachDistance = approachDistance
        self.pinPosition = pinPosition
        self.holeStatExternalId = holeStatExternalId
    }
}

// MARK: - goals

public struct GoalRow: Sendable, Codable, Equatable {
    public let goalId: Int
    public let userId: UUID
    public let goalExternalId: String?
    public let kind: String // discriminator (case name, e.g. "scoreUnderOrEqual")
    public let payload: Data // JSON-encoded associated values
    public let title: String
    public let notes: String?
    public let createdAt: Date
    public let deadline: Date?
    public let archivedAt: Date?
}

public struct GoalInsert: Sendable, Codable, Equatable {
    public let userId: UUID
    public let goalExternalId: String
    public let kind: String
    public let payload: Data
    public let title: String
    public let notes: String?
    public let deadline: Date?

    public init(
        userId: UUID,
        goalExternalId: String,
        kind: String,
        payload: Data,
        title: String,
        notes: String? = nil,
        deadline: Date? = nil
    ) {
        self.userId = userId
        self.goalExternalId = goalExternalId
        self.kind = kind
        self.payload = payload
        self.title = title
        self.notes = notes
        self.deadline = deadline
    }
}

public struct GoalUpdate: Sendable, Codable, Equatable {
    public let title: String?
    public let notes: String?
    public let deadline: Date?
    public let archivedAt: Date?

    public init(
        title: String? = nil,
        notes: String? = nil,
        deadline: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.title = title
        self.notes = notes
        self.deadline = deadline
        self.archivedAt = archivedAt
    }
}

// swiftlint:enable discouraged_optional_boolean
