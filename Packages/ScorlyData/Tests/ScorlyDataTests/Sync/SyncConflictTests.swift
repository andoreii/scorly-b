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
