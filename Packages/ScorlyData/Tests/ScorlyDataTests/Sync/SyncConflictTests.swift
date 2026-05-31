import Foundation
import ScorlyDomain
import SwiftData
import Testing
@testable import ScorlyData

/// Pull-side last-write-wins. Two scenarios:
/// 1. Pulled row is newer than the local cache → local row updates.
/// 2. Pulled row is OLDER than local → no overwrite (LWW respects time).
struct SyncConflictTests {
    @Test("Newer pulled goal overwrites the local version (LWW)")
    func newerPullWins() async throws {
        let fixture = try Fixture()
        let externalId = UUID()
        let userId = UUID()
        // Seed local with createdAt = t0.
        let context = ModelContext(fixture.container)
        let oldData = Data(#"{"original":true}"#.utf8)
        context.insert(
            LocalGoal(
                externalId: externalId,
                userId: userId,
                title: "Old title",
                kindData: oldData,
                createdAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        try context.save()

        // Stage a pulled row that's strictly newer (t1 > t0).
        let newData = Data(#"{"original":false}"#.utf8)
        await fixture.remote.setPullResult(
            RemotePullResult(
                goals: [
                    GoalRow(
                        goalId: 7,
                        userId: userId,
                        goalExternalId: externalId.uuidString,
                        kind: "roundsPlayed",
                        payload: newData,
                        title: "New title",
                        notes: nil,
                        createdAt: Date(timeIntervalSince1970: 2_000),
                        deadline: nil,
                        archivedAt: nil
                    ),
                ],
                observedAt: Date()
            )
        )
        let counts = try await fixture.engine.pullAndReconcile()
        #expect(counts.goals == 1)

        let after = try ModelContext(fixture.container)
            .fetch(FetchDescriptor<LocalGoal>())
            .first
        #expect(after?.title == "New title")
        #expect(after?.kindData == newData)
        #expect(after?.serverId == 7)
    }

    @Test("Older pulled goal is ignored when local is fresher (LWW)")
    func olderPullLoses() async throws {
        let fixture = try Fixture()
        let externalId = UUID()
        let userId = UUID()
        let context = ModelContext(fixture.container)
        context.insert(
            LocalGoal(
                externalId: externalId,
                userId: userId,
                title: "Local fresher",
                kindData: Data("{}".utf8),
                createdAt: Date(timeIntervalSince1970: 5_000)
            )
        )
        try context.save()

        await fixture.remote.setPullResult(
            RemotePullResult(
                goals: [
                    GoalRow(
                        goalId: 1,
                        userId: userId,
                        goalExternalId: externalId.uuidString,
                        kind: "roundsPlayed",
                        payload: Data("{}".utf8),
                        title: "Stale server",
                        notes: nil,
                        createdAt: Date(timeIntervalSince1970: 1_000),
                        deadline: nil,
                        archivedAt: nil
                    ),
                ],
                observedAt: Date()
            )
        )
        let counts = try await fixture.engine.pullAndReconcile()
        #expect(counts.goals == 0)

        let after = try ModelContext(fixture.container)
            .fetch(FetchDescriptor<LocalGoal>())
            .first
        #expect(after?.title == "Local fresher") // Unchanged.
    }

    @Test("Limited round reconciliation persists the pulled hole statistics")
    func limitedRoundReconciliationHydratesHoleStats() async throws {
        let fixture = try Fixture()
        let userId = UUID()
        let courseExternalId = UUID()
        let teeExternalId = UUID()
        let roundExternalId = UUID()
        let statExternalId = UUID()
        let context = ModelContext(fixture.container)
        context.insert(
            LocalCourse(
                serverId: 12,
                externalId: courseExternalId,
                userId: userId,
                name: "Taiyo Golf Course",
                createdAt: Date()
            )
        )
        context.insert(
            LocalTee(
                serverId: 19,
                externalId: teeExternalId,
                courseExternalId: courseExternalId,
                name: "Blue"
            )
        )
        context.insert(
            LocalHole(
                serverId: 101,
                externalId: UUID(),
                courseExternalId: courseExternalId,
                number: 1,
                par: 5
            )
        )
        try context.save()

        let row = RoundRow(
            roundId: 33,
            userId: userId,
            courseId: 12,
            teeId: 19,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: "18",
            roundType: "Casual",
            roundFormat: "Stroke Play",
            conditions: "Sunny",
            temperature: 80,
            walkingVsRiding: "Walking",
            startedAt: nil,
            finishedAt: nil,
            mentalState: 8,
            roundExternalId: roundExternalId.uuidString,
            notes: nil,
            whsDifferential: Decimal(string: "10.3"),
            totalScore: 82,
            createdAt: Date(),
            holeStats: [
                HoleStatRow(
                    holeStatId: 44,
                    roundId: 33,
                    holeNumber: 1,
                    strokes: 6,
                    putts: 2,
                    teeShot: "Fairway",
                    approach: "Short",
                    teeClub: "Driver",
                    approachClub: "7i",
                    penaltyStrokes: 0,
                    greenInReg: false,
                    threePutt: false,
                    girOpportunity: true,
                    fairwayOpportunity: true,
                    upAndDownSuccess: false,
                    sandSaveSuccess: false,
                    puttDistances: [16, 2],
                    teeShotDistance: 244,
                    approachDistance: 164,
                    pinPosition: "Middle",
                    holeStatExternalId: statExternalId.uuidString,
                    createdAt: Date(),
                    penaltyEventsJson: nil,
                    approachLandingDistance: nil,
                    argShotsJson: nil,
                    layupLie: nil,
                    layupDistance: nil
                ),
            ],
            players: nil
        )

        let changed = try await fixture.engine.reconcileRounds([row], localUserId: userId)

        #expect(changed == 1)
        let pulledRound = try #require(
            try ModelContext(fixture.container).fetch(FetchDescriptor<LocalRound>()).first
        )
        #expect(pulledRound.courseExternalId == courseExternalId)
        #expect(pulledRound.teeExternalId == teeExternalId)
        let pulledStat = try #require(
            try ModelContext(fixture.container).fetch(FetchDescriptor<LocalHoleStat>()).first
        )
        #expect(pulledStat.roundExternalId == roundExternalId)
        #expect(pulledStat.par == 5)
        #expect(pulledStat.puttDistances == [16, 2])
    }

    struct Fixture {
        let container: ModelContainer
        let remote: InMemoryRemoteSyncAPI
        let engine: SyncEngine

        init() throws {
            container = try LocalSchema.makeInMemoryContainer()
            remote = InMemoryRemoteSyncAPI()
            engine = SyncEngine.make(
                modelContainer: container,
                remote: remote,
                network: MockNetworkMonitor(initiallyOnline: true),
                configuration: .fast
            )
        }
    }
}
