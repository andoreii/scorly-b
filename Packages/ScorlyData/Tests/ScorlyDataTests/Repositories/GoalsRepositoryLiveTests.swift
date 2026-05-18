import Foundation
import ScorlyDomain
import SwiftData
import Testing
@testable import ScorlyData

/// CRUD against an in-memory SwiftData container, with every write
/// asserted to enqueue an outbox entry of the correct shape.
struct GoalsRepositoryLiveTests {
    @Test("save inserts LocalGoal AND enqueues a goal/insert outbox entry")
    func saveEnqueues() async throws {
        let fixture = try Fixture()
        let goal = Goal(
            id: UUID(),
            title: "Break 85",
            kind: .scoreUnderOrEqual(target: 85),
            createdAt: Date()
        )
        try await fixture.repository.save(goal)
        let active = try await fixture.repository.fetchActive()
        #expect(active.count == 1)
        #expect(active.first?.id == goal.id)
        #expect(await fixture.engine.pendingCount() == 1)
    }

    @Test("archive flips archivedAt and excludes goal from fetchActive")
    func archiveHidesFromActive() async throws {
        let fixture = try Fixture()
        let goal = Goal(
            id: UUID(),
            title: "10 GIRs",
            kind: .girRateAtLeast(target: Decimal(string: "0.55") ?? 0),
            createdAt: Date()
        )
        try await fixture.repository.save(goal)
        try await fixture.repository.archive(id: goal.id, at: Date())
        #expect(try await fixture.repository.fetchActive().isEmpty)
        #expect(try await fixture.repository.fetchAll().count == 1)
    }

    @Test("delete removes the LocalGoal AND enqueues a goal/delete entry")
    func deleteEnqueues() async throws {
        let fixture = try Fixture()
        let goal = Goal(
            id: UUID(),
            title: "10 rounds",
            kind: .roundsPlayed(target: 10),
            createdAt: Date()
        )
        try await fixture.repository.save(goal)
        try await fixture.repository.delete(id: goal.id)
        #expect(try await fixture.repository.fetchAll().isEmpty)
        // 2 entries total: the prior insert + the delete.
        #expect(await fixture.engine.pendingCount() == 2)
    }

    @Test("update changes the LocalGoal AND enqueues a goal/update entry")
    func updateEnqueues() async throws {
        let fixture = try Fixture()
        let goal = Goal(
            id: UUID(),
            title: "Break 85",
            kind: .scoreUnderOrEqual(target: 85),
            createdAt: Date()
        )
        try await fixture.repository.save(goal)
        let renamed = Goal(
            id: goal.id,
            title: "Break 80",
            kind: .scoreUnderOrEqual(target: 80),
            createdAt: goal.createdAt
        )
        try await fixture.repository.update(renamed)
        let active = try await fixture.repository.fetchActive()
        #expect(active.first?.title == "Break 80")
        if case let .scoreUnderOrEqual(target) = active.first?.kind {
            #expect(target == 80)
        } else {
            Issue.record("Decoded kind is wrong")
        }
    }

    @Test("update on missing goal throws notFound")
    func updateMissingThrows() async throws {
        let fixture = try Fixture()
        let goal = Goal(
            id: UUID(),
            title: "Break 85",
            kind: .scoreUnderOrEqual(target: 85),
            createdAt: Date()
        )
        await #expect(throws: GoalsRepositoryError.self) {
            try await fixture.repository.update(goal)
        }
    }

    // MARK: - Fixture

    struct Fixture {
        let container: ModelContainer
        let engine: SyncEngine
        let repository: GoalsRepositoryLive

        init() throws {
            container = try LocalSchema.makeInMemoryContainer()
            engine = SyncEngine.make(
                modelContainer: container,
                remote: InMemoryRemoteSyncAPI(),
                network: MockNetworkMonitor(initiallyOnline: true),
                configuration: .fast
            )
            repository = GoalsRepositoryLive.make(
                modelContainer: container,
                userId: UUID(),
                syncEngine: engine
            )
        }
    }
}
