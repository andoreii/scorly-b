// Optional Bools are deliberate: derived stats (GIR, FIR, 3-putt, up-and-down,
// sand save) carry a third "not applicable" state that a non-optional Bool
// cannot express. Disabling the lint here is the right tradeoff.
// swiftlint:disable discouraged_optional_boolean

import Foundation
import SwiftData

// SwiftData @Model classes mirroring the Supabase schema. Each one has:
// - The DB serial PK as `Int?` (nil until the server assigns it)
// - The client-generated `externalId` UUID (idempotency key, set immediately
//   on local insert so the SyncEngine can deduplicate retries)
// - All scalar columns
// - `init(from row:)` and `update(from row:)` for round-tripping
//
// Why `Int?` for the PK: locally-created records exist before the server
// has assigned a serial. The PK is filled in when a pull merges the
// server's response back. Lookup by `externalId` (UUID) is canonical;
// `id` is just a cache.

@Model
public final class LocalUser {
    @Attribute(.unique)
    public var id: UUID
    public var handicapIndex: Decimal?
    public var createdAt: Date

    public init(id: UUID, handicapIndex: Decimal? = nil, createdAt: Date) {
        self.id = id
        self.handicapIndex = handicapIndex
        self.createdAt = createdAt
    }

    public convenience init(from row: UserRow) {
        self.init(id: row.id, handicapIndex: row.handicapIndex, createdAt: row.createdAt)
    }

    public func update(from row: UserRow) {
        handicapIndex = row.handicapIndex
        createdAt = row.createdAt
    }
}

@Model
public final class LocalCourse {
    public var serverId: Int?
    @Attribute(.unique)
    public var externalId: UUID
    public var userId: UUID
    public var name: String
    public var location: String?
    public var notes: String?
    public var colorTheme: String?
    public var createdAt: Date

    public init(
        serverId: Int? = nil,
        externalId: UUID,
        userId: UUID,
        name: String,
        location: String? = nil,
        notes: String? = nil,
        colorTheme: String? = nil,
        createdAt: Date
    ) {
        self.serverId = serverId
        self.externalId = externalId
        self.userId = userId
        self.name = name
        self.location = location
        self.notes = notes
        self.colorTheme = colorTheme
        self.createdAt = createdAt
    }

    public convenience init?(from row: CourseRow) {
        guard let externalString = row.courseExternalId,
              let externalId = UUID(uuidString: externalString)
        else {
            // Pre-Phase-C historical rows lack `course_external_id`. Skip
            // them in the local cache; they're still server-readable.
            return nil
        }
        self.init(
            serverId: row.courseId,
            externalId: externalId,
            userId: row.userId,
            name: row.courseName,
            location: row.location,
            notes: row.notes,
            colorTheme: row.colorTheme,
            createdAt: row.createdAt
        )
    }

    public func update(from row: CourseRow) {
        serverId = row.courseId
        userId = row.userId
        name = row.courseName
        location = row.location
        notes = row.notes
        colorTheme = row.colorTheme
        createdAt = row.createdAt
    }
}

@Model
public final class LocalTee {
    public var serverId: Int?
    @Attribute(.unique)
    public var externalId: UUID
    public var courseExternalId: UUID // parent reference by external ID
    public var name: String
    public var courseRating: Decimal?
    public var slopeRating: Decimal?
    public var totalYardage: Int?

    public init(
        serverId: Int? = nil,
        externalId: UUID,
        courseExternalId: UUID,
        name: String,
        courseRating: Decimal? = nil,
        slopeRating: Decimal? = nil,
        totalYardage: Int? = nil
    ) {
        self.serverId = serverId
        self.externalId = externalId
        self.courseExternalId = courseExternalId
        self.name = name
        self.courseRating = courseRating
        self.slopeRating = slopeRating
        self.totalYardage = totalYardage
    }

    public func update(from row: TeeRow, courseExternalId: UUID) {
        serverId = row.teeId
        self.courseExternalId = courseExternalId
        name = row.teeName
        courseRating = row.courseRating
        slopeRating = row.slopeRating
        totalYardage = row.yardage
    }
}

@Model
public final class LocalHole {
    public var serverId: Int?
    @Attribute(.unique)
    public var externalId: UUID
    public var courseExternalId: UUID
    public var number: Int
    public var par: Int
    public var handicapIndex: Int?

    public init(
        serverId: Int? = nil,
        externalId: UUID,
        courseExternalId: UUID,
        number: Int,
        par: Int,
        handicapIndex: Int? = nil
    ) {
        self.serverId = serverId
        self.externalId = externalId
        self.courseExternalId = courseExternalId
        self.number = number
        self.par = par
        self.handicapIndex = handicapIndex
    }

    public func update(from row: HoleRow, courseExternalId: UUID) {
        serverId = row.holeId
        self.courseExternalId = courseExternalId
        number = row.holeNumber
        par = row.par
        handicapIndex = row.holeHandicapIndex
    }
}

@Model
public final class LocalTeeHole {
    public var serverId: Int?
    @Attribute(.unique)
    public var externalId: UUID
    public var teeExternalId: UUID
    public var holeNumber: Int
    public var yardage: Int

    public init(
        serverId: Int? = nil,
        externalId: UUID,
        teeExternalId: UUID,
        holeNumber: Int,
        yardage: Int
    ) {
        self.serverId = serverId
        self.externalId = externalId
        self.teeExternalId = teeExternalId
        self.holeNumber = holeNumber
        self.yardage = yardage
    }

    public func update(from row: TeeHoleRow, teeExternalId: UUID) {
        serverId = row.teeHoleId
        self.teeExternalId = teeExternalId
        holeNumber = row.holeNumber
        yardage = row.yardage
    }
}

@Model
public final class LocalRound {
    public var serverId: Int?
    @Attribute(.unique)
    public var externalId: UUID
    public var userId: UUID
    public var courseExternalId: UUID
    public var teeExternalId: UUID?
    public var datePlayed: Date
    public var holesPlayed: String
    public var roundType: String?
    public var roundFormat: String?
    public var conditions: String?
    public var temperature: Int?
    public var walkingVsRiding: String?
    public var startedAt: Date?
    public var finishedAt: Date?
    public var mentalState: Int?
    public var notes: String?
    public var totalScore: Int?
    public var whsDifferential: Decimal?
    public var createdAt: Date
    /// Drafts skip sync until the user hits "save round". The SyncEngine
    /// honours this by not enqueueing outbox entries for `isDraft == true`.
    /// Phase Z3 (round in-progress safety net) replaces v1's UserDefaults
    /// snapshot via this flag.
    public var isDraft: Bool

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        serverId: Int? = nil,
        externalId: UUID,
        userId: UUID,
        courseExternalId: UUID,
        teeExternalId: UUID? = nil,
        datePlayed: Date,
        holesPlayed: String,
        roundType: String? = nil,
        roundFormat: String? = nil,
        conditions: String? = nil,
        temperature: Int? = nil,
        walkingVsRiding: String? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        mentalState: Int? = nil,
        notes: String? = nil,
        totalScore: Int? = nil,
        whsDifferential: Decimal? = nil,
        createdAt: Date,
        isDraft: Bool = false
    ) {
        self.serverId = serverId
        self.externalId = externalId
        self.userId = userId
        self.courseExternalId = courseExternalId
        self.teeExternalId = teeExternalId
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
        self.isDraft = isDraft
    }
}

@Model
public final class LocalHoleStat {
    public var serverId: Int?
    @Attribute(.unique)
    public var externalId: UUID
    public var roundExternalId: UUID
    public var holeNumber: Int
    public var par: Int
    public var strokes: Int
    public var putts: Int
    public var teeShot: String?
    public var approach: String?
    public var teeClub: String?
    public var approachClub: String?
    public var outOfBoundsCount: Int
    public var penaltyStrokes: Int
    public var hazardCount: Int
    public var greenInReg: Bool?
    public var threePutt: Bool?
    public var upAndDownSuccess: Bool?
    public var sandSaveSuccess: Bool?
    public var puttDistances: [Int]?
    public var teeShotDistance: Int?
    public var approachDistance: Int?
    public var pinPosition: String?

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        serverId: Int? = nil,
        externalId: UUID,
        roundExternalId: UUID,
        holeNumber: Int,
        par: Int,
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
        upAndDownSuccess: Bool? = nil,
        sandSaveSuccess: Bool? = nil,
        puttDistances: [Int]? = nil,
        teeShotDistance: Int? = nil,
        approachDistance: Int? = nil,
        pinPosition: String? = nil
    ) {
        self.serverId = serverId
        self.externalId = externalId
        self.roundExternalId = roundExternalId
        self.holeNumber = holeNumber
        self.par = par
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
        self.upAndDownSuccess = upAndDownSuccess
        self.sandSaveSuccess = sandSaveSuccess
        self.puttDistances = puttDistances
        self.teeShotDistance = teeShotDistance
        self.approachDistance = approachDistance
        self.pinPosition = pinPosition
    }
}

@Model
public final class LocalGoal {
    public var serverId: Int?
    @Attribute(.unique)
    public var externalId: UUID
    public var userId: UUID
    public var title: String
    public var notes: String?
    /// JSON encoding of the `GoalKind` enum (with discriminator + payload).
    /// Stored as `Data` because SwiftData has no enum-with-associated-values
    /// support. The `GoalsRepository` decodes back to `GoalKind` on read.
    public var kindData: Data
    public var createdAt: Date
    public var deadline: Date?
    public var archivedAt: Date?

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        serverId: Int? = nil,
        externalId: UUID,
        userId: UUID,
        title: String,
        notes: String? = nil,
        kindData: Data,
        createdAt: Date,
        deadline: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.serverId = serverId
        self.externalId = externalId
        self.userId = userId
        self.title = title
        self.notes = notes
        self.kindData = kindData
        self.createdAt = createdAt
        self.deadline = deadline
        self.archivedAt = archivedAt
    }
}

// MARK: - Container factory

public enum LocalSchema {
    /// Every `@Model` in the data layer. Pass to `ModelContainer` so a
    /// single registration covers the whole app.
    public static let allModels: [any PersistentModel.Type] = [
        LocalUser.self,
        LocalCourse.self,
        LocalTee.self,
        LocalHole.self,
        LocalTeeHole.self,
        LocalRound.self,
        LocalHoleStat.self,
        LocalGoal.self,
        OutboxEntry.self,
    ]

    /// In-memory container — used by tests and by previews. Real apps
    /// build a disk-backed `ModelContainer` via `makeContainer()` below.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(allModels)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Disk-backed container for the running app. Built once in
    /// `ScorlyApp.init` (Phase H) and shared between SwiftUI's
    /// `.modelContainer(_:)` modifier and the `SyncEngine`. CloudKit is
    /// disabled — Scorly's sync goes through Supabase via the outbox.
    public static func makeContainer() throws -> ModelContainer {
        let schema = Schema(allModels)
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

// swiftlint:enable discouraged_optional_boolean
