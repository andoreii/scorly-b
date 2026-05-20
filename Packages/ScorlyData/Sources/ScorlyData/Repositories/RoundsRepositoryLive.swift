import Foundation
import ScorlyDomain
import Supabase
import SwiftData

/// SwiftData-backed `RoundsRepository`. Persists `RoundDraft` + every
/// `HoleStat` as `LocalRound` + `[LocalHoleStat]`, then enqueues outbox
/// entries for each.
///
/// Reads return `[CompletedRound]` — the engine-shaped read aggregate.
/// Drafts (`isDraft == true`) are excluded from reads and from sync; the
/// in-progress round (Phase Z3) lives on the same model but is hidden
/// from goal evaluation until finished.
public actor RoundsRepositoryLive: RoundsRepository {
    nonisolated let userId: UUID
    nonisolated let syncEngine: SyncEngine
    nonisolated let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let supabase: SupabaseClient?

    public static func make(
        modelContainer: ModelContainer,
        userId: UUID,
        syncEngine: SyncEngine,
        supabase: SupabaseClient? = nil
    ) -> RoundsRepositoryLive {
        RoundsRepositoryLive(
            modelContainer: modelContainer,
            userId: userId,
            syncEngine: syncEngine,
            supabase: supabase
        )
    }

    private init(
        modelContainer: ModelContainer,
        userId: UUID,
        syncEngine: SyncEngine,
        supabase: SupabaseClient? = nil
    ) {
        self.modelContainer = modelContainer
        modelContext = ModelContext(modelContainer)
        self.userId = userId
        self.syncEngine = syncEngine
        self.supabase = supabase
    }

    public func fetchAllCompleted() async throws -> [CompletedRound] {
        let courseNames = try courseNameLookup()
        let teeLookup = try teeLookup()
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.isDraft == false },
            sortBy: [SortDescriptor(\.datePlayed, order: .reverse)]
        )
        let rounds = try modelContext.fetch(descriptor)
        return rounds.map { local in
            let stats = fetchHoleStats(for: local.externalId)
            return makeCompleted(
                from: local,
                holeStats: stats,
                courseName: courseNames[local.courseExternalId],
                teeLookup: teeLookup
            )
        }
    }

    public func fetchRecent(limit: Int) async throws -> [CompletedRound] {
        let courseNames = try courseNameLookup()
        let teeLookup = try teeLookup()
        var descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.isDraft == false },
            sortBy: [SortDescriptor(\.datePlayed, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let rounds = try modelContext.fetch(descriptor)
        return rounds.map { local in
            let stats = fetchHoleStats(for: local.externalId)
            return makeCompleted(
                from: local,
                holeStats: stats,
                courseName: courseNames[local.courseExternalId],
                teeLookup: teeLookup
            )
        }
    }

    public func fetchRecentCompleted(
        forCourseExternalId courseExternalId: UUID,
        limit: Int
    ) async throws -> [CompletedRound] {
        guard limit > 0 else { return [] }

        let courseNames = try courseNameLookup()
        let teeLookup = try teeLookup()
        let selectedCourseExternalId = courseExternalId
        var descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate {
                $0.isDraft == false && $0.courseExternalId == selectedCourseExternalId
            },
            sortBy: [SortDescriptor(\.datePlayed, order: .reverse)]
        )
        descriptor.fetchLimit = max(0, limit)
        let rounds = try modelContext.fetch(descriptor)
        return rounds.map { local in
            let stats = fetchHoleStats(for: local.externalId)
            return makeCompleted(
                from: local,
                holeStats: stats,
                courseName: courseNames[local.courseExternalId],
                teeLookup: teeLookup
            )
        }
    }

    public func refreshFromRemote(limit: Int) async throws {
        guard let supabase else { return }
        let userId = userId
        let rows: [RoundRow] = try await supabase
            .from("rounds")
            .select("*, hole_stats(*)")
            .eq("user_id", value: userId)
            .order("date_played", ascending: false)
            .limit(limit)
            .execute()
            .value
        for row in rows {
            guard
                let externalIdString = row.roundExternalId,
                let externalId = UUID(uuidString: externalIdString)
            else { continue }
            let descriptor = FetchDescriptor<LocalRound>(
                predicate: #Predicate { $0.externalId == externalId }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                existing.serverId = row.roundId
                existing.datePlayed = row.datePlayed
                existing.holesPlayed = row.holesPlayed
                existing.roundType = row.roundType
                existing.conditions = row.conditions
                existing.totalScore = row.totalScore
                existing.whsDifferential = row.whsDifferential
            } else {
                let local = LocalRound(
                    serverId: row.roundId,
                    externalId: externalId,
                    userId: row.userId,
                    courseExternalId: UUID(),
                    datePlayed: row.datePlayed,
                    holesPlayed: row.holesPlayed,
                    roundType: row.roundType,
                    conditions: row.conditions,
                    totalScore: row.totalScore,
                    whsDifferential: row.whsDifferential,
                    createdAt: row.createdAt,
                    isDraft: false
                )
                modelContext.insert(local)
            }
        }
        try modelContext.save()
    }

    public func save(_ round: RoundDraft) async throws {
        let playersData = round.players.isEmpty ? nil : try? Self.encoder.encode(round.players)
        let local = LocalRound(
            externalId: round.id,
            userId: round.userId,
            courseExternalId: round.courseId,
            teeExternalId: round.teeId,
            datePlayed: round.datePlayed,
            holesPlayed: round.holesPlayed.rawValue,
            roundType: round.roundType?.rawValue,
            roundFormat: round.roundFormat?.rawValue,
            conditions: Mappings.csv(for: round.conditions),
            temperature: round.temperature,
            walkingVsRiding: round.walkingVsRiding?.rawValue,
            startedAt: round.startedAt,
            finishedAt: round.finishedAt,
            mentalState: round.mentalState,
            notes: round.notes,
            totalScore: round.totalScore,
            whsDifferential: round.whsDifferential,
            createdAt: round.createdAt,
            isDraft: false,
            players: playersData
        )
        modelContext.insert(local)
        // Capture each hole stat's external id once so the local row and the
        // outbox payload reference the same UUID — that's the idempotency
        // key the server-side `hole_stat_external_id` UNIQUE constraint uses
        // to dedupe push retries.
        var pendingHoleStats: [RoundOutboxBody.PendingHoleStat] = []
        pendingHoleStats.reserveCapacity(round.holeStats.count)
        for (index, stat) in round.holeStats.enumerated() {
            let externalId = UUID()
            let statLocal = LocalHoleStat(
                externalId: externalId,
                roundExternalId: round.id,
                holeNumber: index + 1,
                par: stat.par,
                strokes: stat.strokes,
                putts: stat.putts,
                teeShot: Mappings.v1ShotLocation(for: stat.teeShotLie),
                approach: Mappings.v1ShotLocation(for: stat.approachLie),
                outOfBoundsCount: stat.outOfBoundsCount,
                penaltyStrokes: stat.penaltyStrokes,
                hazardCount: stat.hazardCount,
                upAndDownSuccess: stat.upAndDownSuccess,
                sandSaveSuccess: stat.sandSaveSuccess
            )
            modelContext.insert(statLocal)
            pendingHoleStats.append(
                RoundOutboxBody.PendingHoleStat(
                    holeStatExternalId: externalId.uuidString,
                    holeNumber: index + 1,
                    strokes: stat.strokes,
                    putts: stat.putts,
                    teeShot: Mappings.v1ShotLocation(for: stat.teeShotLie),
                    approach: Mappings.v1ShotLocation(for: stat.approachLie),
                    outOfBoundsCount: stat.outOfBoundsCount,
                    penaltyStrokes: stat.penaltyStrokes,
                    hazardCount: stat.hazardCount,
                    upAndDownSuccess: stat.upAndDownSuccess,
                    sandSaveSuccess: stat.sandSaveSuccess
                )
            )
        }
        try modelContext.save()
        let body = makeRoundOutboxBody(from: round, holeStats: pendingHoleStats)
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .round,
                op: .insert,
                externalId: round.id,
                body: Self.encoder.encode(body)
            )
        )
        // Fire-and-forget drain so the round reaches Supabase as soon as the
        // network allows, rather than waiting for the next offline→online
        // flip or the next app launch. Errors are absorbed inside drain
        // (transient → backoff, permanent → dead-letter), so we don't await.
        Task { [syncEngine] in _ = await syncEngine.drain() }
    }

    public func update(_ round: RoundDraft) async throws {
        guard let local = try findLocal(externalId: round.id) else {
            throw RoundsRepositoryError.notFound(round.id)
        }
        local.courseExternalId = round.courseId
        local.teeExternalId = round.teeId
        local.datePlayed = round.datePlayed
        local.holesPlayed = round.holesPlayed.rawValue
        local.roundType = round.roundType?.rawValue
        local.roundFormat = round.roundFormat?.rawValue
        local.conditions = Mappings.csv(for: round.conditions)
        local.temperature = round.temperature
        local.walkingVsRiding = round.walkingVsRiding?.rawValue
        local.startedAt = round.startedAt
        local.finishedAt = round.finishedAt
        local.mentalState = round.mentalState
        local.notes = round.notes
        local.totalScore = round.totalScore
        local.whsDifferential = round.whsDifferential
        try modelContext.save()
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .round,
                op: .update,
                externalId: round.id,
                body: Self.encoder.encode(makeRoundInsert(from: round))
            )
        )
    }

    public func delete(id: UUID) async throws {
        guard let local = try findLocal(externalId: id) else {
            throw RoundsRepositoryError.notFound(id)
        }
        modelContext.delete(local)
        for stat in fetchHoleStats(for: id) {
            modelContext.delete(stat)
        }
        try modelContext.save()
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .round,
                op: .delete,
                externalId: id,
                body: Data("{}".utf8)
            )
        )
    }
}

// MARK: - Internals

private extension RoundsRepositoryLive {
    private func findLocal(externalId: UUID) throws -> LocalRound? {
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.externalId == externalId }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func fetchHoleStats(for roundExternalId: UUID) -> [LocalHoleStat] {
        let descriptor = FetchDescriptor<LocalHoleStat>(
            predicate: #Predicate { $0.roundExternalId == roundExternalId },
            sortBy: [SortDescriptor(\.holeNumber, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func courseNameLookup() throws -> [UUID: String] {
        let courses = try modelContext.fetch(FetchDescriptor<LocalCourse>())
        return Dictionary(uniqueKeysWithValues: courses.map { ($0.externalId, $0.name) })
    }

    private struct TeeLookup {
        let nameByExternalId: [UUID: String]
        let categoryByExternalId: [UUID: TeeCategory]
    }

    private func teeLookup() throws -> TeeLookup {
        let tees = try modelContext.fetch(FetchDescriptor<LocalTee>())
        let nameByExternalId = Dictionary(uniqueKeysWithValues: tees.map { ($0.externalId, $0.name) })

        let byCourse = Dictionary(grouping: tees, by: \.courseExternalId)
        var categoryByExternalId: [UUID: TeeCategory] = [:]
        for (_, courseTees) in byCourse {
            let inputs = courseTees.map {
                TeeCategorization.Tee(
                    externalId: $0.externalId,
                    name: $0.name,
                    yardage: $0.totalYardage
                )
            }
            for (id, category) in TeeCategorization.categorize(tees: inputs) {
                categoryByExternalId[id] = category
            }
        }
        return TeeLookup(
            nameByExternalId: nameByExternalId,
            categoryByExternalId: categoryByExternalId
        )
    }

    private func makeCompleted(
        from local: LocalRound,
        holeStats: [LocalHoleStat],
        courseName: String? = nil,
        teeLookup: TeeLookup
    ) -> CompletedRound {
        let holesPlayed = HolesPlayed(rawValue: local.holesPlayed) ?? .eighteen
        let stats: [HoleStat] = holeStats.map { stat in
            HoleStat(
                par: stat.par,
                strokes: stat.strokes,
                putts: stat.putts,
                teeShotLie: stat.teeShot.flatMap(Mappings.lie(fromV1ShotLocation:)),
                approachLie: stat.approach.flatMap(Mappings.lie(fromV1ShotLocation:)),
                penaltyStrokes: stat.penaltyStrokes,
                outOfBoundsCount: stat.outOfBoundsCount,
                hazardCount: stat.hazardCount,
                upAndDownSuccess: stat.upAndDownSuccess ?? false,
                sandSaveSuccess: stat.sandSaveSuccess ?? false
            )
        }
        let par = stats.reduce(0) { $0 + $1.par }
        let roundType = local.roundType.flatMap(RoundType.init(rawValue:))
        let roundFormat = local.roundFormat.flatMap(RoundFormat.init(rawValue:))
        let conditions = local.conditions.map(Mappings.conditions(fromCSV:)) ?? []
        let walkingVsRiding = local.walkingVsRiding.flatMap(WalkingVsRiding.init(rawValue:))
        let teeName = local.teeExternalId.flatMap { teeLookup.nameByExternalId[$0] }
        let teeCategory = local.teeExternalId.flatMap { teeLookup.categoryByExternalId[$0] }
        return CompletedRound(
            id: local.externalId,
            datePlayed: local.datePlayed,
            par: par,
            totalScore: local.totalScore ?? stats.reduce(0) { $0 + $1.strokes },
            holesPlayed: holesPlayed,
            courseRating: nil,
            slope: nil,
            holeStats: stats,
            sgTotals: nil,
            roundType: roundType,
            roundFormat: roundFormat,
            conditions: conditions,
            courseName: courseName,
            courseExternalId: local.courseExternalId,
            teeName: teeName,
            teeCategory: teeCategory,
            walkingVsRiding: walkingVsRiding
        )
    }

    private func makeRoundOutboxBody(
        from draft: RoundDraft,
        holeStats: [RoundOutboxBody.PendingHoleStat]
    ) -> RoundOutboxBody {
        RoundOutboxBody(
            courseExternalId: draft.courseId,
            teeExternalId: draft.teeId,
            userId: draft.userId,
            datePlayed: SupabaseConfig.dateOnlyFormatter.string(from: draft.datePlayed),
            holesPlayed: draft.holesPlayed.rawValue,
            roundType: draft.roundType?.rawValue,
            roundFormat: draft.roundFormat?.rawValue,
            conditions: Mappings.csv(for: draft.conditions),
            temperature: draft.temperature,
            walkingVsRiding: draft.walkingVsRiding?.rawValue,
            startedAt: draft.startedAt,
            finishedAt: draft.finishedAt,
            mentalState: draft.mentalState,
            roundExternalId: draft.id.uuidString,
            notes: draft.notes,
            whsDifferential: draft.whsDifferential,
            totalScore: draft.totalScore,
            players: draft.players,
            holeStats: holeStats
        )
    }

    private func makeRoundInsert(from draft: RoundDraft) -> RoundInsert {
        RoundInsert(
            userId: draft.userId,
            courseId: 0, // Update path: server-side lookup pending until Phase D round-edit lands.
            teeId: nil,
            datePlayed: SupabaseConfig.dateOnlyFormatter.string(from: draft.datePlayed),
            holesPlayed: draft.holesPlayed.rawValue,
            roundType: draft.roundType?.rawValue,
            roundFormat: draft.roundFormat?.rawValue,
            conditions: Mappings.csv(for: draft.conditions),
            temperature: draft.temperature,
            walkingVsRiding: draft.walkingVsRiding?.rawValue,
            startedAt: draft.startedAt,
            finishedAt: draft.finishedAt,
            mentalState: draft.mentalState,
            roundExternalId: draft.id.uuidString,
            notes: draft.notes,
            whsDifferential: draft.whsDifferential,
            totalScore: draft.totalScore
        )
    }

    static let encoder = SupabaseConfig.encoder
}

public enum RoundsRepositoryError: Error, Sendable, Equatable {
    case notFound(UUID)
}
