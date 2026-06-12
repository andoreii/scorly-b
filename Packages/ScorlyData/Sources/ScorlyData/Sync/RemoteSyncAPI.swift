import Foundation
import ScorlyDomain
import Supabase
import SwiftData

/// The SyncEngine talks to the remote (Supabase) through this protocol; tests pass an in-memory fake.
public protocol RemoteSyncAPI: Sendable {
    /// Pushes one outbox entry, returning the server-assigned ID for inserts (nil otherwise).
    func push(_ payload: PushPayload) async throws -> RemotePushResult

    /// Pulls every record changed since `since` (or all, if nil) for reconciliation.
    func pull(since: Date?) async throws -> RemotePullResult
}

public struct PushPayload: Sendable, Equatable {
    public let aggregate: OutboxAggregate
    public let op: OutboxOperation
    public let externalId: UUID
    public let body: Data

    public init(
        aggregate: OutboxAggregate,
        op: OutboxOperation,
        externalId: UUID,
        body: Data
    ) {
        self.aggregate = aggregate
        self.op = op
        self.externalId = externalId
        self.body = body
    }
}

public struct RemotePushResult: Sendable, Equatable {
    /// The server's serial ID for the row, when the op inserted one.
    public let serverId: Int?

    public init(serverId: Int? = nil) {
        self.serverId = serverId
    }
}

public struct RemotePullResult: Sendable, Equatable {
    public let users: [UserRow]
    public let courses: [CourseRow]
    public let rounds: [RoundRow]
    public let goals: [GoalRow]
    public let observedAt: Date

    public init(
        users: [UserRow] = [],
        courses: [CourseRow] = [],
        rounds: [RoundRow] = [],
        goals: [GoalRow] = [],
        observedAt: Date
    ) {
        self.users = users
        self.courses = courses
        self.rounds = rounds
        self.goals = goals
        self.observedAt = observedAt
    }
}

/// Classifies errors into retry-with-backoff vs give-up-and-dead-letter.
public enum RemoteSyncError: Error, Sendable, Equatable {
    case transient(String)
    case permanent(String)
}

enum CourseMockupColorTheme {
    private static let themes = [
        "Sand",
        "Forest",
        "Clay",
        "Mist",
        "Rose",
        "Pine",
        "Wheat",
        "Ash",
        "Terracotta",
        "Bronze",
    ]

    static func colorTheme(for row: CourseRow, index: Int) -> String? {
        if row.courseName.localizedCaseInsensitiveContains("taiyo") {
            return "Rose"
        }
        if themes.indices.contains(index) {
            return themes[index]
        }
        return row.colorTheme
    }
}

// MARK: - In-memory fake (for tests + previews)

/// Test fake: records pushes for assertions, can simulate transient failures and stage pull results.
public actor InMemoryRemoteSyncAPI: RemoteSyncAPI {
    public private(set) var pushes: [PushPayload] = []
    public private(set) var pullCount = 0
    private var pushFailureBudget = 0
    private var nextPullResult: RemotePullResult?
    private var nextServerIdByAggregate: [OutboxAggregate: Int] = [:]

    public init() {}

    public func push(_ payload: PushPayload) async throws -> RemotePushResult {
        if pushFailureBudget > 0 {
            pushFailureBudget -= 1
            throw RemoteSyncError.transient("simulated outage")
        }
        pushes.append(payload)
        guard payload.op == .insert else {
            return RemotePushResult(serverId: nil)
        }
        let next = (nextServerIdByAggregate[payload.aggregate] ?? 0) + 1
        nextServerIdByAggregate[payload.aggregate] = next
        return RemotePushResult(serverId: next)
    }

    public func pull(since _: Date?) async throws -> RemotePullResult {
        pullCount += 1
        return nextPullResult ?? RemotePullResult(observedAt: Date())
    }

    public func injectPushFailure(times: Int) {
        pushFailureBudget = times
    }

    public func setPullResult(_ result: RemotePullResult) {
        nextPullResult = result
    }

    public func pushes(for aggregate: OutboxAggregate) -> [PushPayload] {
        pushes.filter { $0.aggregate == aggregate }
    }
}

protocol HoleStatsRemoteAPI: Sendable {
    func upsert(_ rows: [HoleStatInsert]) async throws
}

struct LiveHoleStatsRemoteAPI: HoleStatsRemoteAPI {
    let supabase: SupabaseClient

    func upsert(_ rows: [HoleStatInsert]) async throws {
        guard !rows.isEmpty else { return }
        try await supabase
            .from("hole_stats")
            .upsert(rows, onConflict: "round_id,hole_number", returning: .minimal)
            .execute()
    }
}

// MARK: - Live placeholder

/// Live Supabase remote. Only round push + course/round pull are wired so far;
/// other aggregates throw until their write UIs land.
public struct LiveSupabaseRemoteSyncAPI: RemoteSyncAPI {
    private let supabase: SupabaseClient
    /// Resolves course/tee external IDs to Supabase serial IDs for FK columns; nil disables pushes.
    private let modelContainer: ModelContainer?

    public init(
        supabase: SupabaseClient = SupabaseClientFactory.make(),
        modelContainer: ModelContainer? = nil
    ) {
        self.supabase = supabase
        self.modelContainer = modelContainer
    }

    public func push(_ payload: PushPayload) async throws -> RemotePushResult {
        switch (payload.aggregate, payload.op) {
        case (.round, .insert):
            return try await pushRoundInsert(payload.body)
        default:
            throw RemoteSyncError.permanent(
                "Live Supabase push not wired for \(payload.aggregate)/\(payload.op)"
            )
        }
    }

    private func pushRoundInsert(_ body: Data) async throws -> RemotePushResult {
        guard let modelContainer else {
            throw RemoteSyncError.permanent(
                "LiveSupabaseRemoteSyncAPI built without a ModelContainer; cannot resolve course/tee ids"
            )
        }
        let outboxBody: RoundOutboxBody
        do {
            outboxBody = try SupabaseConfig.decoder.decode(RoundOutboxBody.self, from: body)
        } catch {
            throw RemoteSyncError.permanent("malformed round outbox body: \(error)")
        }
        let lookup = LocalIdResolver(container: modelContainer)
        guard let courseServerId = lookup.courseServerId(for: outboxBody.courseExternalId) else {
            // Not yet pulled; retry once the next pull populates the cache.
            throw RemoteSyncError.transient(
                "course \(outboxBody.courseExternalId) not yet synced"
            )
        }
        let teeServerId: Int? = outboxBody.teeExternalId.flatMap(lookup.teeServerId(for:))

        let insert = RoundInsert(
            userId: outboxBody.userId,
            courseId: courseServerId,
            teeId: teeServerId,
            datePlayed: outboxBody.datePlayed,
            holesPlayed: outboxBody.holesPlayed,
            roundType: outboxBody.roundType,
            roundFormat: outboxBody.roundFormat,
            conditions: outboxBody.conditions,
            temperature: outboxBody.temperature,
            walkingVsRiding: outboxBody.walkingVsRiding,
            startedAt: outboxBody.startedAt,
            finishedAt: outboxBody.finishedAt,
            mentalState: outboxBody.mentalState,
            roundExternalId: outboxBody.roundExternalId,
            notes: outboxBody.notes,
            whsDifferential: outboxBody.whsDifferential,
            totalScore: outboxBody.totalScore,
            players: outboxBody.players
        )

        let inserted: [RoundRow]
        do {
            inserted = try await supabase
                .from("rounds")
                .upsert(
                    insert,
                    onConflict: "round_external_id",
                    returning: .representation
                )
                .select()
                .execute()
                .value
        } catch {
            throw classify(error)
        }

        guard let roundId = inserted.first?.roundId else {
            throw RemoteSyncError.permanent("rounds insert returned no rows")
        }

        if !outboxBody.holeStats.isEmpty {
            let holeStatInserts = outboxBody.holeStats.map { stat in
                HoleStatInsert(
                    roundId: roundId,
                    holeNumber: stat.holeNumber,
                    strokes: stat.strokes,
                    putts: stat.putts,
                    teeShot: stat.teeShot,
                    approach: stat.approach,
                    teeClub: stat.teeClub,
                    approachClub: stat.approachClub,
                    penaltyStrokes: stat.penaltyStrokes,
                    greenInReg: stat.greenInReg,
                    threePutt: stat.threePutt,
                    girOpportunity: stat.girOpportunity,
                    fairwayOpportunity: stat.fairwayOpportunity,
                    upAndDownSuccess: stat.upAndDownSuccess,
                    sandSaveSuccess: stat.sandSaveSuccess,
                    puttDistances: stat.puttDistances,
                    teeShotDistance: stat.teeShotDistance,
                    approachDistance: stat.approachDistance,
                    pinPosition: stat.pinPosition,
                    holeStatExternalId: stat.holeStatExternalId,
                    penaltyEventsJson: stat.penaltyEventsJson,
                    approachLandingDistance: stat.approachLandingDistance,
                    argShotsJson: stat.argShotsJson,
                    layupLie: stat.layupLie,
                    layupDistance: stat.layupDistance
                )
            }
            do {
                try await LiveHoleStatsRemoteAPI(supabase: supabase)
                    .upsert(holeStatInserts)
            } catch {
                throw classify(error)
            }
        }

        return RemotePushResult(serverId: roundId)
    }

    public func pull(since _: Date?) async throws -> RemotePullResult {
        do {
            let courses = try await fetchCourses()
            let rounds = try await fetchRounds()
            let coloredCourses = Self.applyingMockupColors(to: courses)
            await persistMockupColorsIfNeeded(original: courses, colored: coloredCourses)
            return RemotePullResult(courses: coloredCourses, rounds: rounds, observedAt: Date())
        } catch {
            throw classify(error)
        }
    }

    private func fetchCourses() async throws -> [CourseRow] {
        do {
            return try await selectCourses(columns: Self.courseSelect)
        } catch {
            // Fall back for schemas without the nested relationship names PostgREST needs.
            return try await selectCourses(columns: Self.scalarCourseSelect)
        }
    }

    private func selectCourses(columns: String) async throws -> [CourseRow] {
        try await supabase
            .from("courses")
            .select(columns)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func fetchRounds() async throws -> [RoundRow] {
        try await supabase
            .from("rounds")
            .select("*, hole_stats(*)")
            .order("date_played", ascending: false)
            .execute()
            .value
    }

    private func persistMockupColorsIfNeeded(
        original: [CourseRow],
        colored: [CourseRow]
    ) async {
        for (old, new) in zip(original, colored) where old.colorTheme != new.colorTheme {
            do {
                try await supabase
                    .from("courses")
                    .update(
                        CourseUpdate(colorTheme: new.colorTheme),
                        returning: .minimal
                    )
                    .eq("course_id", value: old.courseId)
                    .execute()
            } catch {
                // Best-effort: don't block course display if this patch fails.
            }
        }
    }

    private func classify(_ error: Error) -> RemoteSyncError {
        let message = error.localizedDescription
        if error is URLError {
            return .transient(message)
        }
        return .permanent(message)
    }

    private static let courseSelect = "*, tees(*, tee_holes(*)), holes(*)"

    private static let scalarCourseSelect = "*"

    /// Synchronous cache lookup for course/tee server IDs.
    private struct LocalIdResolver {
        let container: ModelContainer

        func courseServerId(for externalId: UUID) -> Int? {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<LocalCourse>(
                predicate: #Predicate { $0.externalId == externalId }
            )
            return (try? context.fetch(descriptor))?.first?.serverId
        }

        func teeServerId(for externalId: UUID) -> Int? {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<LocalTee>(
                predicate: #Predicate { $0.externalId == externalId }
            )
            return (try? context.fetch(descriptor))?.first?.serverId
        }
    }

    private static func applyingMockupColors(to rows: [CourseRow]) -> [CourseRow] {
        rows.enumerated().map { index, row in
            let colorTheme = CourseMockupColorTheme.colorTheme(for: row, index: index)
            return CourseRow(
                courseId: row.courseId,
                userId: row.userId,
                courseName: row.courseName,
                location: row.location,
                notes: row.notes,
                colorTheme: colorTheme,
                courseExternalId: row.courseExternalId,
                createdAt: row.createdAt,
                tees: row.tees,
                holes: row.holes
            )
        }
    }
}
