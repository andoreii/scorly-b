import Foundation
import ScorlyDomain
import SwiftData

/// Owns the outbox lifecycle: drains queued writes to Supabase (on explicit
/// drain, network reconnect, or BG refresh) with exponential backoff, and
/// pulls + merges remote changes using last-write-wins by `createdAt`.
public actor SyncEngine {
    nonisolated let remote: RemoteSyncAPI
    nonisolated let network: NetworkMonitor
    nonisolated let configuration: SyncConfiguration
    nonisolated let clock: SyncClock
    nonisolated let modelContainer: ModelContainer
    let modelContext: ModelContext
    private var lastPullDate: Date?
    private var watcherTask: Task<Void, Never>?

    /// Builds a dedicated `ModelContext` so the actor's serial executor owns it.
    public static func make(
        modelContainer: ModelContainer,
        remote: RemoteSyncAPI,
        network: NetworkMonitor,
        configuration: SyncConfiguration = .default,
        clock: SyncClock = .live
    ) -> SyncEngine {
        SyncEngine(
            modelContainer: modelContainer,
            remote: remote,
            network: network,
            configuration: configuration,
            clock: clock
        )
    }

    private init(
        modelContainer: ModelContainer,
        remote: RemoteSyncAPI,
        network: NetworkMonitor,
        configuration: SyncConfiguration,
        clock: SyncClock
    ) {
        self.modelContainer = modelContainer
        modelContext = ModelContext(modelContainer)
        self.remote = remote
        self.network = network
        self.configuration = configuration
        self.clock = clock
    }

    // MARK: - Public API

    /// Queue a payload; callers pre-build the JSON body so the engine stays agnostic of aggregate shapes.
    public func enqueue(_ entry: PendingOutbox) throws {
        let outbox = OutboxEntry(
            aggregate: entry.aggregate,
            op: entry.op,
            externalId: entry.externalId,
            payload: entry.body,
            createdAt: clock.now()
        )
        modelContext.insert(outbox)
        try modelContext.save()
    }

    /// Drains ready entries (nextAttemptAt nil or past, FIFO by createdAt).
    /// Permanent errors dead-letter the entry; transient errors reschedule with backoff.
    @discardableResult
    public func drain() async -> SyncDrainResult {
        guard await network.isOnline() else {
            return SyncDrainResult(pushed: 0, retried: 0, deadLettered: 0)
        }
        let entries = readyEntries()
        var pushed = 0
        var retried = 0
        var deadLettered = 0
        for entry in entries {
            guard let aggregate = entry.aggregateKind, let op = entry.operationKind else {
                deadLettered += 1
                continue
            }
            let payload = PushPayload(
                aggregate: aggregate,
                op: op,
                externalId: entry.externalId,
                body: entry.payload
            )
            do {
                _ = try await remote.push(payload)
                modelContext.delete(entry)
                try? modelContext.save()
                pushed += 1
            } catch let error as RemoteSyncError {
                switch error {
                case let .transient(message):
                    schedule(entry, error: message)
                    retried += 1
                case let .permanent(message):
                    if entry.attempts + 1 >= configuration.maxAttempts {
                        entry.lastError = "permanent: \(message)"
                        try? modelContext.save()
                        deadLettered += 1
                    } else {
                        // Dead-letter but keep in outbox for visibility.
                        entry.lastError = "permanent: \(message)"
                        entry.attempts += 1
                        try? modelContext.save()
                        deadLettered += 1
                    }
                }
            } catch {
                schedule(entry, error: String(describing: error))
                retried += 1
            }
        }
        return SyncDrainResult(
            pushed: pushed,
            retried: retried,
            deadLettered: deadLettered
        )
    }

    /// Drains the outbox on every offline → online flip. Idempotent.
    public func startWatchingNetwork() async {
        guard watcherTask == nil else { return }
        let stream = await network.updates()
        watcherTask = Task { [weak self] in
            for await online in stream {
                guard let self else { return }
                if online {
                    _ = await drain()
                }
            }
        }
    }

    public func stopWatchingNetwork() {
        watcherTask?.cancel()
        watcherTask = nil
    }

    /// Pulls from remote and merges into local SwiftData, last-write-wins by `createdAt`.
    @discardableResult
    public func pullAndReconcile(
        forceNetworkAttempt: Bool = false,
        localCourseUserId: UUID? = nil
    ) async throws -> SyncPullCounts {
        if !forceNetworkAttempt {
            guard await network.isOnline() else { return .empty }
        }
        let result = try await remote.pull(since: lastPullDate)
        let users = mergeUsers(result.users)
        let courses = mergeCourses(result.courses, localUserId: localCourseUserId)
        let rounds = mergeRounds(result.rounds, localUserId: localCourseUserId)
        let goals = mergeGoals(result.goals)
        try modelContext.save()
        lastPullDate = result.observedAt
        return SyncPullCounts(
            users: users,
            courses: courses,
            rounds: rounds,
            goals: goals
        )
    }

    /// Reconciles a caller-selected window of remote rounds via the same merge path as a full pull.
    @discardableResult
    func reconcileRounds(_ rows: [RoundRow], localUserId: UUID? = nil) throws -> Int {
        let rounds = mergeRounds(rows, localUserId: localUserId)
        try modelContext.save()
        return rounds
    }

    /// Outbox depth — exposed for tests + diagnostics dashboards.
    public func pendingCount() -> Int {
        let descriptor = FetchDescriptor<OutboxEntry>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Internals

    private func readyEntries() -> [OutboxEntry] {
        let now = clock.now()
        let descriptor = FetchDescriptor<OutboxEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all.filter { entry in
            guard let next = entry.nextAttemptAt else { return true }
            return next <= now
        }
    }

    private func schedule(_ entry: OutboxEntry, error: String) {
        entry.attempts += 1
        entry.lastError = error
        if entry.attempts >= configuration.maxAttempts {
            entry.nextAttemptAt = nil
            return
        }
        let delay = configuration.backoff(forAttempt: entry.attempts)
        entry.nextAttemptAt = clock.now().addingTimeInterval(delay)
        try? modelContext.save()
    }
}

// MARK: - Supporting types

public struct SyncConfiguration: Sendable {
    public let maxAttempts: Int
    public let baseBackoff: TimeInterval
    public let maxBackoff: TimeInterval

    public init(maxAttempts: Int, baseBackoff: TimeInterval, maxBackoff: TimeInterval) {
        self.maxAttempts = maxAttempts
        self.baseBackoff = baseBackoff
        self.maxBackoff = maxBackoff
    }

    public static let `default` = Self(
        maxAttempts: 5,
        baseBackoff: 1,
        maxBackoff: 60
    )

    /// Compressed backoff curve for tests.
    public static let fast = Self(
        maxAttempts: 5,
        baseBackoff: 0.001,
        maxBackoff: 0.01
    )

    func backoff(forAttempt attempt: Int) -> TimeInterval {
        let exponent = max(0, attempt - 1)
        let raw = baseBackoff * pow(2.0, Double(exponent))
        return min(raw, maxBackoff)
    }
}

public struct PendingOutbox: Sendable, Equatable {
    public let aggregate: OutboxAggregate
    public let op: OutboxOperation
    public let externalId: UUID
    public let body: Data

    public init(aggregate: OutboxAggregate, op: OutboxOperation, externalId: UUID, body: Data) {
        self.aggregate = aggregate
        self.op = op
        self.externalId = externalId
        self.body = body
    }
}

public struct SyncDrainResult: Sendable, Equatable {
    public let pushed: Int
    public let retried: Int
    public let deadLettered: Int

    public init(pushed: Int, retried: Int, deadLettered: Int) {
        self.pushed = pushed
        self.retried = retried
        self.deadLettered = deadLettered
    }
}

public struct SyncPullCounts: Sendable, Equatable {
    public let users: Int
    public let courses: Int
    public let rounds: Int
    public let goals: Int

    public init(users: Int, courses: Int, rounds: Int, goals: Int) {
        self.users = users
        self.courses = courses
        self.rounds = rounds
        self.goals = goals
    }

    public static let empty = Self(users: 0, courses: 0, rounds: 0, goals: 0)
}

/// Indirection over `Date()` so tests can advance time deterministically.
public struct SyncClock: Sendable {
    public let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }

    public static let live = Self { Date() }
}
