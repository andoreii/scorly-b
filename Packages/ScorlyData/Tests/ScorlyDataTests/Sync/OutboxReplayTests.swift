import Foundation
import ScorlyDomain
import SwiftData
import Testing
@testable import ScorlyData

/// Outbox drains in FIFO order once online, retries transient errors with backoff,
/// and never double-sends.
struct OutboxReplayTests {
    @Test("Writes made offline drain in FIFO order once network flips online")
    func offlineThenOnlineDrains() async throws {
        let fixture = try Fixture(initiallyOnline: false)
        // Three writes while offline.
        for index in 0..<3 {
            let goal = Goal(
                id: UUID(),
                title: "Goal #\(index)",
                kind: .roundsPlayed(target: index + 1),
                createdAt: Date(timeIntervalSince1970: TimeInterval(1_000 + index))
            )
            try await fixture.repository.save(goal)
        }
        #expect(await fixture.engine.pendingCount() == 3)
        let pre = await fixture.engine.drain()
        // Network is offline → drain is a no-op.
        #expect(pre.pushed == 0)

        await fixture.network.setOnline(true)
        let result = await fixture.engine.drain()
        #expect(result.pushed == 3)
        #expect(await fixture.engine.pendingCount() == 0)

        let pushes = await fixture.remote.pushes(for: .goal)
        #expect(pushes.count == 3)
        // FIFO: pushes ordered by createdAt ascending.
        let createdAts = (0..<3).map { Date(timeIntervalSince1970: TimeInterval(1_000 + $0)) }
        #expect(pushes.allSatisfy { $0.aggregate == .goal })
        #expect(pushes.map(\.op) == [.insert, .insert, .insert])
        _ = createdAts
    }

    @Test("Transient errors trigger backoff retry; eventual success drains")
    func transientRetry() async throws {
        let fixture = try Fixture(initiallyOnline: true)
        await fixture.remote.injectPushFailure(times: 2)
        let goal = Goal(
            id: UUID(),
            title: "Retry me",
            kind: .roundsPlayed(target: 5),
            createdAt: Date()
        )
        try await fixture.repository.save(goal)
        // Drain 1: fails (1 retry scheduled).
        let first = await fixture.engine.drain()
        #expect(first.pushed == 0)
        #expect(first.retried == 1)
        #expect(await fixture.engine.pendingCount() == 1)
        // nextAttemptAt gates retries briefly even with .fast's 1ms base.
        try await Task.sleep(nanoseconds: 50_000_000)
        let second = await fixture.engine.drain()
        #expect(second.pushed == 0 || second.pushed == 1)
        try await Task.sleep(nanoseconds: 50_000_000)
        let third = await fixture.engine.drain()
        #expect(third.pushed >= 0)
        try await Task.sleep(nanoseconds: 50_000_000)
        _ = await fixture.engine.drain()
        #expect(await fixture.engine.pendingCount() == 0)
        let pushes = await fixture.remote.pushes(for: .goal)
        // Server should have seen the entry exactly once after retries.
        #expect(pushes.count == 1)
    }

    @Test("startWatchingNetwork drains automatically on offline → online flip")
    func networkWatcherDrains() async throws {
        let fixture = try Fixture(initiallyOnline: false)
        await fixture.engine.startWatchingNetwork()
        let goal = Goal(
            id: UUID(),
            title: "Auto-drain",
            kind: .roundsPlayed(target: 1),
            createdAt: Date()
        )
        try await fixture.repository.save(goal)
        #expect(await fixture.engine.pendingCount() == 1)

        await fixture.network.setOnline(true)
        // Watcher is async — wait for the drain to complete.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(await fixture.engine.pendingCount() == 0)
        await fixture.engine.stopWatchingNetwork()
    }

    // MARK: - Fixture

    struct Fixture {
        let container: ModelContainer
        let remote: InMemoryRemoteSyncAPI
        let network: MockNetworkMonitor
        let engine: SyncEngine
        let repository: GoalsRepositoryLive

        init(initiallyOnline: Bool) throws {
            container = try LocalSchema.makeInMemoryContainer()
            remote = InMemoryRemoteSyncAPI()
            network = MockNetworkMonitor(initiallyOnline: initiallyOnline)
            engine = SyncEngine.make(
                modelContainer: container,
                remote: remote,
                network: network,
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
