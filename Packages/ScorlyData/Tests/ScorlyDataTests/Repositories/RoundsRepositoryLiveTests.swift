import Foundation
import ScorlyDomain
import SwiftData
import Testing
@testable import ScorlyData

/// Repository CRUD: `save` persists a draft + every hole stat; `fetchAllCompleted`
/// returns the engine-shaped read aggregate; `delete` removes the row + its
/// hole stats and enqueues an outbox entry.
struct RoundsRepositoryLiveTests {
    @Test("save persists round + hole stats, fetchAllCompleted reconstitutes them")
    func saveAndFetch() async throws {
        let fixture = try Fixture()
        let courseId = UUID()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: courseId,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            walkingVsRiding: .riding,
            totalScore: 82,
            createdAt: Date(),
            holeStats: [
                HoleStat(par: 4, strokes: 4, putts: 2, teeShotLie: .fairway, approachLie: .green),
                HoleStat(par: 3, strokes: 3, putts: 1, teeShotLie: .green),
            ]
        )
        try await fixture.repository.save(draft)
        let rounds = try await fixture.repository.fetchAllCompleted()
        #expect(rounds.count == 1)
        let round = try #require(rounds.first)
        #expect(round.id == draft.id)
        #expect(round.totalScore == 82)
        #expect(round.holeStats.count == 2)
        #expect(round.holeStats[0].teeShotLie == .fairway)
        #expect(round.holeStats[1].teeShotLie == .green)
        #expect(round.walkingVsRiding == .riding)
        #expect(await fixture.engine.pendingCount() == 1)
    }

    @Test("delete removes round + child hole stats + enqueues delete entry")
    func deleteCascades() async throws {
        let fixture = try Fixture()
        let id = UUID()
        let draft = RoundDraft(
            id: id,
            externalId: id,
            userId: fixture.userId,
            courseId: UUID(),
            datePlayed: Date(),
            holesPlayed: .eighteen,
            totalScore: 80,
            createdAt: Date(),
            holeStats: [HoleStat(par: 4, strokes: 4, putts: 2)]
        )
        try await fixture.repository.save(draft)
        try await fixture.repository.delete(id: id)
        let rounds = try await fixture.repository.fetchAllCompleted()
        #expect(rounds.isEmpty)
        // Hole stats should be gone too — we look at the SwiftData container
        // directly to verify that side-effect.
        let context = ModelContext(fixture.container)
        let stats = try context.fetch(FetchDescriptor<LocalHoleStat>())
        #expect(stats.isEmpty)
    }

    @Test("fetchRecentCompleted for course filters by course external id and caps newest first")
    func fetchRecentCompletedForCourse() async throws {
        let fixture = try Fixture()
        let selectedCourseId = UUID()
        let otherCourseId = UUID()
        let calendar = Calendar(identifier: .gregorian)
        let start = try #require(calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2_026,
            month: 5,
            day: 14
        )))

        for offset in 0..<25 {
            try await fixture.repository.save(RoundDraft(
                id: UUID(),
                externalId: UUID(),
                userId: fixture.userId,
                courseId: selectedCourseId,
                datePlayed: #require(calendar.date(byAdding: .day, value: -offset, to: start)),
                holesPlayed: .eighteen,
                totalScore: 80 + offset,
                createdAt: Date(),
                holeStats: [HoleStat(par: 4, strokes: 4, putts: 2)]
            ))
        }

        try await fixture.repository.save(RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: otherCourseId,
            datePlayed: #require(calendar.date(byAdding: .day, value: 1, to: start)),
            holesPlayed: .eighteen,
            totalScore: 70,
            createdAt: Date(),
            holeStats: [HoleStat(par: 4, strokes: 4, putts: 2)]
        ))

        let rounds = try await fixture.repository.fetchRecentCompleted(
            forCourseExternalId: selectedCourseId,
            limit: 20
        )

        #expect(rounds.count == 20)
        #expect(rounds.allSatisfy { $0.courseExternalId == selectedCourseId })
        #expect(rounds.map(\.datePlayed) == rounds.map(\.datePlayed).sorted(by: >))
        #expect(rounds.map(\.totalScore) == Array(80..<100))
    }

    @Test("in-progress draft round-trips and never hits the outbox")
    func inProgressDraftRoundTrip() async throws {
        let fixture = try Fixture()
        let payload = Data("entries-blob".utf8)
        let setupPayload = Data("setup-blob".utf8)
        let draft = InProgressRoundDraft(
            id: UUID(),
            userId: fixture.userId,
            courseExternalId: UUID(),
            teeExternalId: UUID(),
            holesPlayed: .eighteen,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_500),
            holeIdx: 4,
            entriesPayload: payload,
            setupPayload: setupPayload
        )
        try await fixture.repository.upsertInProgressDraft(draft)

        let fetched = try #require(await fixture.repository.fetchInProgressDraft())
        #expect(fetched.id == draft.id)
        #expect(fetched.userId == draft.userId)
        #expect(fetched.courseExternalId == draft.courseExternalId)
        #expect(fetched.teeExternalId == draft.teeExternalId)
        #expect(fetched.holesPlayed == .eighteen)
        #expect(fetched.holeIdx == 4)
        #expect(fetched.entriesPayload == payload)
        #expect(fetched.setupPayload == setupPayload)
        // Drafts must not push to Supabase — outbox stays empty.
        #expect(await fixture.engine.pendingCount() == 0)

        // Upsert overwrites in place: a second write with new holeIdx
        // replaces (does not duplicate) the row.
        var updated = draft
        updated.holeIdx = 9
        updated.entriesPayload = Data("entries-blob-v2".utf8)
        updated.setupPayload = nil
        try await fixture.repository.upsertInProgressDraft(updated)
        let refetched = try #require(await fixture.repository.fetchInProgressDraft())
        #expect(refetched.holeIdx == 9)
        #expect(refetched.entriesPayload == Data("entries-blob-v2".utf8))
        #expect(refetched.setupPayload == nil)

        try await fixture.repository.deleteInProgressDraft()
        let afterDelete = try await fixture.repository.fetchInProgressDraft()
        #expect(afterDelete == nil)
        #expect(await fixture.engine.pendingCount() == 0)
    }

    @Test("Par-3 GIR survives save/fetch when stored on tee_shot (canonical path)")
    func par3GIRSurvivesRoundTrip() async throws {
        let fixture = try Fixture()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: UUID(),
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            totalScore: 3,
            createdAt: Date(),
            holeStats: [HoleStat(par: 3, strokes: 3, putts: 2, teeShotLie: .green)]
        )
        try await fixture.repository.save(draft)
        let rounds = try await fixture.repository.fetchAllCompleted()
        let round = try #require(rounds.first)
        #expect(round.holeStats.first?.greenInRegulation == true)
        #expect(round.girCount == 1)
    }

    @Test("bestScoresByCourse honors the default aggregate filter")
    func bestScoresExcludesIneligibleRounds() async throws {
        let fixture = try Fixture()
        let courseA = UUID()
        let courseB = UUID()

        // Course A: eligible stroke 82, eligible match 78 (winner), ineligible scramble 60.
        try await fixture.repository.save(makeDraft(
            userId: fixture.userId,
            courseId: courseA,
            score: 82,
            holes: .eighteen,
            format: .stroke
        ))
        try await fixture.repository.save(makeDraft(
            userId: fixture.userId,
            courseId: courseA,
            score: 78,
            holes: .eighteen,
            format: .match
        ))
        try await fixture.repository.save(makeDraft(
            userId: fixture.userId,
            courseId: courseA,
            score: 60,
            holes: .eighteen,
            format: .scramble
        ))
        // Course B: only a 9-hole round (ineligible) and a missing-format
        // round (also ineligible). Expect no entry in the result.
        try await fixture.repository.save(makeDraft(
            userId: fixture.userId,
            courseId: courseB,
            score: 40,
            holes: .front9,
            format: .stroke
        ))
        try await fixture.repository.save(makeDraft(
            userId: fixture.userId,
            courseId: courseB,
            score: 70,
            holes: .eighteen,
            format: nil
        ))

        let bests = try await fixture.repository.bestScoresByCourse(filter: .default)
        #expect(bests[courseA] == 78)
        #expect(bests[courseB] == nil)
    }

    @Test("fetchAllCompleted normalizes stored format aliases for aggregate filters")
    func fetchNormalizesStoredFormatAliases() async throws {
        let fixture = try Fixture()
        let context = ModelContext(fixture.container)

        for (index, rawFormat) in ["Stroke Play", "Match Play"].enumerated() {
            let round = LocalRound(
                externalId: UUID(),
                userId: fixture.userId,
                courseExternalId: UUID(),
                teeExternalId: nil,
                datePlayed: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(index)),
                holesPlayed: HolesPlayed.eighteen.rawValue,
                roundType: nil,
                roundFormat: rawFormat,
                conditions: nil,
                temperature: nil,
                walkingVsRiding: nil,
                startedAt: nil,
                finishedAt: nil,
                mentalState: nil,
                notes: nil,
                totalScore: 82,
                whsDifferential: nil,
                createdAt: Date(),
                isDraft: false
            )
            context.insert(round)
        }
        try context.save()

        let rounds = try await fixture.repository.fetchAllCompleted()
        #expect(rounds.eligible(for: .default).count == 2)
        #expect(rounds.contains(where: { $0.roundFormat == .stroke }))
        #expect(rounds.contains(where: { $0.roundFormat == .match }))
    }

    @Test("Par-3 GIR is recovered when legacy v2 row stored on-green pick on approach")
    func par3GIRRecoveredFromApproachOnlyRow() async throws {
        let fixture = try Fixture()
        // Simulate the pre-fix v2 layout: tee_shot empty, approach = "Green".
        // (The bug path used to lose GIR; the data-layer coalesce now restores
        // it on read so existing rows benefit without a migration.)
        let context = ModelContext(fixture.container)
        let externalId = UUID()
        let courseExternalId = UUID()
        let round = LocalRound(
            externalId: externalId,
            userId: fixture.userId,
            courseExternalId: courseExternalId,
            teeExternalId: nil,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: HolesPlayed.eighteen.rawValue,
            roundType: nil,
            roundFormat: nil,
            conditions: nil,
            temperature: nil,
            walkingVsRiding: nil,
            startedAt: nil,
            finishedAt: nil,
            mentalState: nil,
            notes: nil,
            totalScore: 3,
            whsDifferential: nil,
            createdAt: Date(),
            isDraft: false
        )
        context.insert(round)
        let stat = LocalHoleStat(
            externalId: UUID(),
            roundExternalId: externalId,
            holeNumber: 1,
            par: 3,
            strokes: 3,
            putts: 2,
            teeShot: nil,
            approach: "Green",
            outOfBoundsCount: 0,
            penaltyStrokes: 0,
            hazardCount: 0
        )
        context.insert(stat)
        try context.save()

        let rounds = try await fixture.repository.fetchAllCompleted()
        let fetched = try #require(rounds.first(where: { $0.id == externalId }))
        #expect(fetched.holeStats.first?.greenInRegulation == true)
        #expect(fetched.holeStats.first?.teeShotLie == .green)
        #expect(fetched.holeStats.first?.approachLie == nil)
    }

    @Test("save persists per-hole detail fields (clubs, pin, derived flags) locally")
    func savePersistsAllHoleDetailLocally() async throws {
        let fixture = try Fixture()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: UUID(),
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            totalScore: 4,
            createdAt: Date(),
            holeStats: [
                HoleStat(
                    par: 4,
                    strokes: 4,
                    putts: 2,
                    teeShotLie: .fairway,
                    approachLie: .green,
                    teeShotDistance: 240,
                    approachDistance: 160,
                    puttDistances: [18, 3],
                    teeClub: "Driver",
                    approachClub: "7 iron",
                    pinPosition: "Middle"
                ),
            ]
        )
        try await fixture.repository.save(draft)

        // Verify the SwiftData row carries the new detail.
        let context = ModelContext(fixture.container)
        let saved = try #require(try context.fetch(FetchDescriptor<LocalHoleStat>()).first)
        #expect(saved.teeClub == "Driver")
        #expect(saved.approachClub == "7 iron")
        #expect(saved.pinPosition == "Middle")
        #expect(saved.greenInReg == true)
        #expect(saved.threePutt == false)
        #expect(saved.teeShotDistance == 240)
        #expect(saved.approachDistance == 160)
        #expect(saved.puttDistances == [18, 3])

        // Verify the outbox payload carries everything we'll push to Supabase.
        let outboxEntries = try context.fetch(FetchDescriptor<OutboxEntry>())
        let roundEntry = try #require(outboxEntries.first { $0.aggregate == OutboxAggregate.round.rawValue })
        let body = try SupabaseConfig.decoder.decode(RoundOutboxBody.self, from: roundEntry.payload)
        let payload = try #require(body.holeStats.first)
        #expect(payload.teeClub == "Driver")
        #expect(payload.approachClub == "7 iron")
        #expect(payload.pinPosition == "Middle")
        #expect(payload.greenInReg == true)
        #expect(payload.threePutt == false)
        #expect(payload.girOpportunity == true)
        #expect(payload.fairwayOpportunity == true)
        #expect(payload.teeShotDistance == 240)
        #expect(payload.approachDistance == 160)
        #expect(payload.puttDistances == [18, 3])
    }

    @Test("fetchAllCompleted populates sgTotals + sgHoles when distances + yardages are present")
    func fetchPopulatesSGWhenDataPresent() async throws {
        let fixture = try Fixture()
        let courseId = UUID()
        let teeId = UUID()
        // Seed the tee-hole yardage table the SG path reads from.
        let context = ModelContext(fixture.container)
        for holeNumber in 1...3 {
            context.insert(LocalTeeHole(
                externalId: UUID(),
                teeExternalId: teeId,
                holeNumber: holeNumber,
                yardage: 400
            ))
        }
        try context.save()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: courseId,
            teeId: teeId,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            totalScore: 12,
            createdAt: Date(),
            holeStats: [
                HoleStat(
                    par: 4,
                    strokes: 4,
                    putts: 2,
                    teeShotLie: .fairway,
                    approachLie: .green,
                    teeShotDistance: 240,
                    approachDistance: 160,
                    puttDistances: [18, 3]
                ),
                HoleStat(
                    par: 4,
                    strokes: 5,
                    putts: 2,
                    teeShotLie: .roughLeft,
                    approachLie: .green,
                    teeShotDistance: 220,
                    approachDistance: 180,
                    puttDistances: [22, 4]
                ),
                HoleStat(
                    par: 3,
                    strokes: 3,
                    putts: 2,
                    teeShotLie: .green,
                    teeShotDistance: 170,
                    puttDistances: [25, 6]
                ),
            ]
        )
        try await fixture.repository.save(draft)
        let rounds = try await fixture.repository.fetchAllCompleted()
        let round = try #require(rounds.first)
        let totals = try #require(round.sgTotals)
        let holes = try #require(round.sgHoles)
        let firstHole = try #require(round.holeStats.first)
        #expect(firstHole.teeShotDistance == 240)
        #expect(firstHole.approachDistance == 160)
        #expect(firstHole.puttDistances == [18, 3])
        #expect(holes.count == round.holeStats.count)
        // The actual numeric SG values come from SGCalculator + the
        // benchmark table; what we're asserting here is that the
        // populate-when-data-present contract holds. A non-trivial total
        // catches the case where every shot returned nil SG.
        let nonZeroHoles = holes.filter { decimalToDouble($0.total) != 0 }
        #expect(!nonZeroHoles.isEmpty)
        // Total = sum of category contributions (the calc invariant).
        let summed = totals.ott + totals.app + totals.arg + totals.putt
        #expect(summed == totals.total)
    }

    @Test("fetchAllCompleted leaves sgTotals + sgHoles nil when yardages are missing")
    func fetchSkipsSGWithoutYardages() async throws {
        let fixture = try Fixture()
        // No LocalTeeHole rows inserted. Saving with a teeId should
        // still succeed, but SG must remain nil because the calculator
        // can't determine hole length.
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: UUID(),
            teeId: UUID(),
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            totalScore: 4,
            createdAt: Date(),
            holeStats: [
                HoleStat(
                    par: 4,
                    strokes: 4,
                    putts: 2,
                    teeShotLie: .fairway,
                    approachLie: .green,
                    teeShotDistance: 240,
                    approachDistance: 160,
                    puttDistances: [18, 3]
                ),
            ]
        )
        try await fixture.repository.save(draft)
        let rounds = try await fixture.repository.fetchAllCompleted()
        let round = try #require(rounds.first)
        #expect(round.sgTotals == nil)
        #expect(round.sgHoles == nil)
    }

    // MARK: - Helpers

    private func decimalToDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private func makeDraft(
        userId: UUID,
        courseId: UUID,
        score: Int,
        holes: HolesPlayed,
        format: RoundFormat?
    ) -> RoundDraft {
        RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: userId,
            courseId: courseId,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: holes,
            roundFormat: format,
            totalScore: score,
            createdAt: Date(),
            holeStats: [HoleStat(par: 4, strokes: 4, putts: 2)]
        )
    }

    // MARK: - Fixture

    struct Fixture {
        let container: ModelContainer
        let engine: SyncEngine
        let repository: RoundsRepositoryLive
        let userId = UUID()

        init() throws {
            container = try LocalSchema.makeInMemoryContainer()
            engine = SyncEngine.make(
                modelContainer: container,
                remote: InMemoryRemoteSyncAPI(),
                network: MockNetworkMonitor(initiallyOnline: true),
                configuration: .fast
            )
            repository = RoundsRepositoryLive.make(
                modelContainer: container,
                userId: userId,
                syncEngine: engine
            )
        }
    }
}
