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
        let yardages = try teeHoleYardageLookup()
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
                teeLookup: teeLookup,
                yardages: yardages
            )
        }
    }

    public func fetchRecent(limit: Int) async throws -> [CompletedRound] {
        let courseNames = try courseNameLookup()
        let teeLookup = try teeLookup()
        let yardages = try teeHoleYardageLookup()
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
                teeLookup: teeLookup,
                yardages: yardages
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
        let yardages = try teeHoleYardageLookup()
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
                teeLookup: teeLookup,
                yardages: yardages
            )
        }
    }

    public func bestScoresByCourse(filter: AggregateRoundFilter) async throws -> [UUID: Int] {
        let teeLookup = try teeLookup()
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.isDraft == false }
        )
        let rounds = try modelContext.fetch(descriptor)
        var best: [UUID: Int] = [:]
        for local in rounds {
            // Lightweight projection — we deliberately skip hydrating
            // LocalHoleStat since AggregateRoundFilter only inspects
            // metadata columns.
            guard
                let holesPlayed = HolesPlayed(rawValue: local.holesPlayed),
                let totalScore = local.totalScore
            else { continue }
            let format = local.roundFormat.flatMap(Mappings.roundFormat(fromUILabel:))
            let type = local.roundType.flatMap(RoundType.init(rawValue:))
            let tee = local.teeExternalId.flatMap { teeLookup.nameByExternalId[$0] }
            guard aggregateFilterIncludes(
                format: format,
                type: type,
                holes: holesPlayed,
                tee: tee,
                filter: filter
            )
            else { continue }
            if let prev = best[local.courseExternalId] {
                best[local.courseExternalId] = min(prev, totalScore)
            } else {
                best[local.courseExternalId] = totalScore
            }
        }
        return best
    }

    public func refreshFromRemote(limit: Int) async throws -> Int {
        guard let supabase else {
            throw RoundsRepositoryError.remoteUnavailable
        }
        let userId = userId
        let rows: [RoundRow] = try await supabase
            .from("rounds")
            .select("*, hole_stats(*)")
            .eq("user_id", value: userId)
            .order("date_played", ascending: false)
            .limit(limit)
            .execute()
            .value
        return try await syncEngine.reconcileRounds(rows, localUserId: userId)
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
                teeClub: stat.teeClub,
                approachClub: stat.approachClub,
                outOfBoundsCount: stat.outOfBoundsCount,
                penaltyStrokes: stat.penaltyStrokes,
                hazardCount: stat.hazardCount,
                greenInReg: stat.greenInRegulation,
                threePutt: stat.threePutt,
                upAndDownSuccess: stat.upAndDownSuccess,
                sandSaveSuccess: stat.sandSaveSuccess,
                puttDistances: stat.puttDistances,
                teeShotDistance: stat.teeShotDistance,
                approachDistance: stat.approachDistance,
                pinPosition: stat.pinPosition,
                outOfBoundsLeft: stat.outOfBoundsLeft,
                outOfBoundsRight: stat.outOfBoundsRight,
                outOfBoundsLong: stat.outOfBoundsLong,
                outOfBoundsShort: stat.outOfBoundsShort,
                hazardLeft: stat.hazardLeft,
                hazardRight: stat.hazardRight,
                hazardLong: stat.hazardLong,
                hazardShort: stat.hazardShort
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
                    teeClub: stat.teeClub,
                    approachClub: stat.approachClub,
                    outOfBoundsCount: stat.outOfBoundsCount,
                    penaltyStrokes: stat.penaltyStrokes,
                    hazardCount: stat.hazardCount,
                    greenInReg: stat.greenInRegulation,
                    threePutt: stat.threePutt,
                    girOpportunity: true,
                    fairwayOpportunity: stat.fairwayOpportunity,
                    upAndDownSuccess: stat.upAndDownSuccess,
                    sandSaveSuccess: stat.sandSaveSuccess,
                    puttDistances: stat.puttDistances,
                    teeShotDistance: stat.teeShotDistance,
                    approachDistance: stat.approachDistance,
                    pinPosition: stat.pinPosition,
                    outOfBoundsLeft: stat.outOfBoundsLeft,
                    outOfBoundsRight: stat.outOfBoundsRight,
                    outOfBoundsLong: stat.outOfBoundsLong,
                    outOfBoundsShort: stat.outOfBoundsShort,
                    hazardLeft: stat.hazardLeft,
                    hazardRight: stat.hazardRight,
                    hazardLong: stat.hazardLong,
                    hazardShort: stat.hazardShort
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

    public func fetchInProgressDraft() async throws -> InProgressRoundDraft? {
        guard let local = try findLocalDraft() else { return nil }
        let holesPlayed = HolesPlayed(rawValue: local.holesPlayed) ?? .eighteen
        return InProgressRoundDraft(
            id: local.draftId,
            userId: local.userId,
            courseExternalId: local.courseExternalId,
            teeExternalId: local.teeExternalId,
            holesPlayed: holesPlayed,
            startedAt: local.startedAt,
            updatedAt: local.updatedAt,
            holeIdx: local.holeIdx,
            entriesPayload: local.entriesPayload,
            setupPayload: local.setupPayload
        )
    }

    public func upsertInProgressDraft(_ draft: InProgressRoundDraft) async throws {
        if let existing = try findLocalDraft() {
            existing.draftId = draft.id
            existing.courseExternalId = draft.courseExternalId
            existing.teeExternalId = draft.teeExternalId
            existing.holesPlayed = draft.holesPlayed.rawValue
            existing.startedAt = draft.startedAt
            existing.updatedAt = draft.updatedAt
            existing.holeIdx = draft.holeIdx
            existing.entriesPayload = draft.entriesPayload
            existing.setupPayload = draft.setupPayload
        } else {
            let local = LocalRoundDraft(
                userId: draft.userId,
                draftId: draft.id,
                courseExternalId: draft.courseExternalId,
                teeExternalId: draft.teeExternalId,
                holesPlayed: draft.holesPlayed.rawValue,
                startedAt: draft.startedAt,
                updatedAt: draft.updatedAt,
                holeIdx: draft.holeIdx,
                entriesPayload: draft.entriesPayload,
                setupPayload: draft.setupPayload
            )
            modelContext.insert(local)
        }
        try modelContext.save()
    }

    public func deleteInProgressDraft() async throws {
        guard let local = try findLocalDraft() else { return }
        modelContext.delete(local)
        try modelContext.save()
    }

    public func backfillHoleStatsToCloud() async throws -> Int {
        guard let supabase else {
            throw RoundsRepositoryError.remoteUnavailable
        }
        // Only rounds that already landed in Supabase (serverId != nil)
        // are candidates — rows without serverId still have an outbox
        // insert entry that will carry the full payload when it drains.
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.isDraft == false }
        )
        let locals = try modelContext.fetch(descriptor)

        // Collect (external id, patch) pairs across every round + hole.
        // The schema's UNIQUE index on `hole_stat_external_id` is
        // partial (`WHERE hole_stat_external_id IS NOT NULL`), so
        // Postgres rejects it as an `ON CONFLICT` target — we PATCH
        // each row by external id instead of upserting.
        var patches: [(externalId: String, patch: HoleStatPatch)] = []
        for local in locals where local.serverId != nil {
            for stat in fetchHoleStats(for: local.externalId) {
                patches.append((
                    externalId: stat.externalId.uuidString,
                    patch: HoleStatPatch(
                        teeShot: stat.teeShot,
                        approach: stat.approach,
                        teeClub: stat.teeClub,
                        approachClub: stat.approachClub,
                        outOfBoundsCount: stat.outOfBoundsCount,
                        penaltyStrokes: stat.penaltyStrokes,
                        hazardCount: stat.hazardCount,
                        greenInReg: stat.greenInReg,
                        threePutt: stat.threePutt,
                        girOpportunity: true,
                        fairwayOpportunity: stat.par >= 4,
                        upAndDownSuccess: stat.upAndDownSuccess,
                        sandSaveSuccess: stat.sandSaveSuccess,
                        puttDistances: stat.puttDistances,
                        teeShotDistance: stat.teeShotDistance,
                        approachDistance: stat.approachDistance,
                        pinPosition: stat.pinPosition,
                        outOfBoundsLeft: stat.outOfBoundsLeft,
                        outOfBoundsRight: stat.outOfBoundsRight,
                        outOfBoundsLong: stat.outOfBoundsLong,
                        outOfBoundsShort: stat.outOfBoundsShort,
                        hazardLeft: stat.hazardLeft,
                        hazardRight: stat.hazardRight,
                        hazardLong: stat.hazardLong,
                        hazardShort: stat.hazardShort
                    )
                ))
            }
        }
        guard !patches.isEmpty else { return 0 }
        for entry in patches {
            do {
                try await supabase
                    .from("hole_stats")
                    .update(entry.patch, returning: .minimal)
                    .eq("hole_stat_external_id", value: entry.externalId)
                    .execute()
            } catch {
                throw RoundsRepositoryError.backfillFailed(error.localizedDescription)
            }
        }
        return patches.count
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

    private func findLocalDraft() throws -> LocalRoundDraft? {
        let scopedUserId = userId
        let descriptor = FetchDescriptor<LocalRoundDraft>(
            predicate: #Predicate { $0.userId == scopedUserId }
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

    /// Per-tee, per-hole yardage map. Used to feed `SGCalculator` with
    /// the hole length each shot started from. One global fetch, then a
    /// nested-dictionary lookup keyed `[teeExternalId][holeNumber]`.
    private func teeHoleYardageLookup() throws -> [UUID: [Int: Int]] {
        let teeHoles = try modelContext.fetch(FetchDescriptor<LocalTeeHole>())
        var byTee: [UUID: [Int: Int]] = [:]
        for th in teeHoles {
            byTee[th.teeExternalId, default: [:]][th.holeNumber] = th.yardage
        }
        return byTee
    }

    private func makeCompleted(
        from local: LocalRound,
        holeStats: [LocalHoleStat],
        courseName: String? = nil,
        teeLookup: TeeLookup,
        yardages: [UUID: [Int: Int]]
    ) -> CompletedRound {
        let holesPlayed = HolesPlayed(rawValue: local.holesPlayed) ?? .eighteen
        let stats: [HoleStat] = holeStats.map { stat in
            let teeLie = stat.teeShot.flatMap(Mappings.lie(fromV1ShotLocation:))
            let approachLie = stat.approach.flatMap(Mappings.lie(fromV1ShotLocation:))
            // Par 3 is a single shot — historical v1 wrote it on tee_shot,
            // some early v2 rounds wrote it on approach. Coalesce on read so
            // the domain's par-3 GIR rule (which inspects teeShotLie) fires
            // either way.
            let resolvedTee: Lie?
            let resolvedApproach: Lie?
            if stat.par == 3 {
                resolvedTee = teeLie ?? approachLie
                resolvedApproach = nil
            } else {
                resolvedTee = teeLie
                resolvedApproach = approachLie
            }
            return HoleStat(
                par: stat.par,
                strokes: stat.strokes,
                putts: stat.putts,
                teeShotLie: resolvedTee,
                approachLie: resolvedApproach,
                penaltyStrokes: stat.penaltyStrokes,
                outOfBoundsCount: stat.outOfBoundsCount,
                hazardCount: stat.hazardCount,
                upAndDownSuccess: stat.upAndDownSuccess ?? false,
                sandSaveSuccess: stat.sandSaveSuccess ?? false,
                teeShotDistance: stat.teeShotDistance,
                approachDistance: stat.approachDistance,
                puttDistances: stat.puttDistances,
                teeClub: stat.teeClub,
                approachClub: stat.approachClub,
                pinPosition: stat.pinPosition,
                outOfBoundsLeft: stat.outOfBoundsLeft,
                outOfBoundsRight: stat.outOfBoundsRight,
                outOfBoundsLong: stat.outOfBoundsLong,
                outOfBoundsShort: stat.outOfBoundsShort,
                hazardLeft: stat.hazardLeft,
                hazardRight: stat.hazardRight,
                hazardLong: stat.hazardLong,
                hazardShort: stat.hazardShort
            )
        }
        let par = stats.reduce(0) { $0 + $1.par }
        let roundType = local.roundType.flatMap(RoundType.init(rawValue:))
        let roundFormat = local.roundFormat.flatMap(Mappings.roundFormat(fromUILabel:))
        let conditions = local.conditions.map(Mappings.conditions(fromCSV:)) ?? []
        let walkingVsRiding = local.walkingVsRiding.flatMap(WalkingVsRiding.init(rawValue:))
        let teeName = local.teeExternalId.flatMap { teeLookup.nameByExternalId[$0] }
        let teeCategory = local.teeExternalId.flatMap { teeLookup.categoryByExternalId[$0] }
        let sg = computeSG(local: local, localStats: holeStats, stats: stats, yardages: yardages)
        return CompletedRound(
            id: local.externalId,
            datePlayed: local.datePlayed,
            par: par,
            totalScore: local.totalScore ?? stats.reduce(0) { $0 + $1.strokes },
            holesPlayed: holesPlayed,
            courseRating: nil,
            slope: nil,
            holeStats: stats,
            sgTotals: sg.totals,
            sgHoles: sg.holes,
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

    /// Strokes Gained for a finished round, if every played hole carries
    /// the minimum data the calculator needs: a tee yardage from
    /// `LocalTeeHole` + recorded putt distances. Rounds logged before
    /// distance capture was wired (v1 imports) fail this gate and get
    /// `nil` SG; the detail view renders its placeholder card in that case.
    ///
    /// `SGCalculator` itself is tolerant of partial per-shot data
    /// (missing distances → nil per-shot SG, aggregates skip nils), so
    /// the gate here is a UX choice — distinguish "round had no SG
    /// logging" from "round was a flat scratch performance".
    private func computeSG(
        local: LocalRound,
        localStats: [LocalHoleStat],
        stats: [HoleStat],
        yardages: [UUID: [Int: Int]]
    ) -> (totals: SGTotals?, holes: [SGTotals]?) {
        guard !localStats.isEmpty, !stats.isEmpty else { return (nil, nil) }
        guard
            let teeExternalId = local.teeExternalId,
            let perHoleYardage = yardages[teeExternalId]
        else { return (nil, nil) }
        let canCompute = localStats.allSatisfy { stat in
            perHoleYardage[stat.holeNumber] != nil && stat.puttDistances != nil
        }
        guard canCompute else { return (nil, nil) }
        let inputs: [HoleSGInput] = zip(localStats, stats).map { localStat, domainStat in
            HoleSGInput(
                par: domainStat.par,
                yardage: perHoleYardage[localStat.holeNumber] ?? 0,
                teeShotLie: domainStat.teeShotLie,
                teeShotDistance: localStat.teeShotDistance,
                approachLie: domainStat.approachLie,
                approachDistance: localStat.approachDistance,
                puttDistancesFeet: localStat.puttDistances,
                strokes: domainStat.strokes
            )
        }
        let result = SGCalculator.compute(holes: inputs)
        return (result.totals, result.holes.map(\.totals))
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

public enum RoundsRepositoryError: Error, LocalizedError, Sendable, Equatable {
    case notFound(UUID)
    /// Repository wasn't constructed with a Supabase client (e.g. in-memory
    /// preview path). The operation requires a network round-trip.
    case remoteUnavailable
    /// A retroactive backfill push failed. The wrapped string is the
    /// underlying error's `localizedDescription` for surface in UI.
    case backfillFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .notFound(id):
            "Round \(id.uuidString.prefix(8)) not found"
        case .remoteUnavailable:
            "Supabase client not configured on this repository"
        case let .backfillFailed(message):
            "Backfill push failed: \(message)"
        }
    }
}
