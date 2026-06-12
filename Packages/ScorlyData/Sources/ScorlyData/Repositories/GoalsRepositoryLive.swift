import Foundation
import ScorlyDomain
import SwiftData

/// SwiftData-backed `GoalsRepository`. Local-first: writes the `LocalGoal` row and
/// enqueues its outbox entry in the same `ModelContext` save.
public actor GoalsRepositoryLive: GoalsRepository {
    nonisolated let userId: UUID
    nonisolated let syncEngine: SyncEngine
    nonisolated let modelContainer: ModelContainer
    private let modelContext: ModelContext

    public static func make(
        modelContainer: ModelContainer,
        userId: UUID,
        syncEngine: SyncEngine
    ) -> GoalsRepositoryLive {
        GoalsRepositoryLive(
            modelContainer: modelContainer,
            userId: userId,
            syncEngine: syncEngine
        )
    }

    private init(modelContainer: ModelContainer, userId: UUID, syncEngine: SyncEngine) {
        self.modelContainer = modelContainer
        modelContext = ModelContext(modelContainer)
        self.userId = userId
        self.syncEngine = syncEngine
    }

    // MARK: - Reads

    public func fetchActive() async throws -> [Goal] {
        try fetchLocals(includeArchived: false).compactMap(decodeGoal)
    }

    public func fetchAll() async throws -> [Goal] {
        try fetchLocals(includeArchived: true).compactMap(decodeGoal)
    }

    // MARK: - Writes

    public func save(_ goal: Goal) async throws {
        let kindData = try Self.encoder.encode(goal.kind)
        let local = LocalGoal(
            externalId: goal.id,
            userId: userId,
            title: goal.title,
            kindData: kindData,
            createdAt: goal.createdAt,
            deadline: goal.deadline,
            archivedAt: goal.archivedAt
        )
        modelContext.insert(local)
        try modelContext.save()
        let insert = GoalInsert(
            userId: userId,
            goalExternalId: goal.id.uuidString,
            kind: Self.discriminator(for: goal.kind),
            payload: kindData,
            title: goal.title,
            notes: nil,
            deadline: goal.deadline
        )
        let body = try Self.encoder.encode(insert)
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .goal,
                op: .insert,
                externalId: goal.id,
                body: body
            )
        )
    }

    public func update(_ goal: Goal) async throws {
        guard let local = try findLocal(externalId: goal.id) else {
            throw GoalsRepositoryError.notFound(goal.id)
        }
        let kindData = try Self.encoder.encode(goal.kind)
        local.title = goal.title
        local.kindData = kindData
        local.deadline = goal.deadline
        local.archivedAt = goal.archivedAt
        try modelContext.save()
        let update = GoalUpdate(
            title: goal.title,
            notes: nil,
            deadline: goal.deadline,
            archivedAt: goal.archivedAt
        )
        let body = try Self.encoder.encode(update)
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .goal,
                op: .update,
                externalId: goal.id,
                body: body
            )
        )
    }

    public func archive(id: UUID, at date: Date) async throws {
        guard let local = try findLocal(externalId: id) else {
            throw GoalsRepositoryError.notFound(id)
        }
        local.archivedAt = date
        try modelContext.save()
        let update = GoalUpdate(archivedAt: date)
        let body = try Self.encoder.encode(update)
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .goal,
                op: .archive,
                externalId: id,
                body: body
            )
        )
    }

    public func delete(id: UUID) async throws {
        guard let local = try findLocal(externalId: id) else {
            throw GoalsRepositoryError.notFound(id)
        }
        modelContext.delete(local)
        try modelContext.save()
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .goal,
                op: .delete,
                externalId: id,
                body: Data("{}".utf8)
            )
        )
    }

    // MARK: - Internals

    private func fetchLocals(includeArchived: Bool) throws -> [LocalGoal] {
        let descriptor: FetchDescriptor<LocalGoal>
        if includeArchived {
            descriptor = FetchDescriptor<LocalGoal>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<LocalGoal>(
                predicate: #Predicate { $0.archivedAt == nil },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    private func findLocal(externalId: UUID) throws -> LocalGoal? {
        let descriptor = FetchDescriptor<LocalGoal>(
            predicate: #Predicate { $0.externalId == externalId }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func decodeGoal(_ local: LocalGoal) -> Goal? {
        guard let kind = try? Self.decoder.decode(GoalKind.self, from: local.kindData) else {
            return nil
        }
        return Goal(
            id: local.externalId,
            title: local.title,
            kind: kind,
            createdAt: local.createdAt,
            deadline: local.deadline,
            archivedAt: local.archivedAt
        )
    }

    // MARK: - Static helpers

    /// Explicit switch so a new `GoalKind` case is a compile error here, not a silent gap.
    static func discriminator(for kind: GoalKind) -> String {
        switch kind {
        case .scoreUnderOrEqual: "scoreUnderOrEqual"
        case .handicapBelowOrEqual: "handicapBelowOrEqual"
        case .girRateAtLeast: "girRateAtLeast"
        case .firRateAtLeast: "firRateAtLeast"
        case .threePuttRateAtMost: "threePuttRateAtMost"
        case .sgCategoryAtLeast: "sgCategoryAtLeast"
        case .roundsPlayed: "roundsPlayed"
        }
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

public enum GoalsRepositoryError: Error, Sendable, Equatable {
    case notFound(UUID)
}
