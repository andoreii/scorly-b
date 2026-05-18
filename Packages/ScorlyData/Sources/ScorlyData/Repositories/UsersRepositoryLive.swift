import Foundation
import ScorlyDomain
import SwiftData

/// SwiftData-backed `UsersRepository`. Tiny — the table only carries the
/// auth UUID, current handicap, and createdAt. Mirrors v1's
/// `AuthService.ensureUserProfile()`.
public actor UsersRepositoryLive: UsersRepository {
    nonisolated let userId: UUID
    nonisolated let syncEngine: SyncEngine
    nonisolated let modelContainer: ModelContainer
    private let modelContext: ModelContext

    public static func make(
        modelContainer: ModelContainer,
        userId: UUID,
        syncEngine: SyncEngine
    ) -> UsersRepositoryLive {
        UsersRepositoryLive(
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

    public func fetchProfile() async throws -> User? {
        let id = userId
        let descriptor = FetchDescriptor<LocalUser>(
            predicate: #Predicate { $0.id == id }
        )
        guard let local = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return User(
            id: local.id,
            handicapIndex: local.handicapIndex,
            createdAt: local.createdAt
        )
    }

    public func upsertProfile(_ user: User) async throws {
        let id = user.id
        let descriptor = FetchDescriptor<LocalUser>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.handicapIndex = user.handicapIndex
            existing.createdAt = user.createdAt
        } else {
            modelContext.insert(
                LocalUser(
                    id: user.id,
                    handicapIndex: user.handicapIndex,
                    createdAt: user.createdAt
                )
            )
        }
        try modelContext.save()
        let insert = UserInsert(id: user.id, handicapIndex: user.handicapIndex)
        let body = try SupabaseConfig.encoder.encode(insert)
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .user,
                op: .insert,
                externalId: user.id,
                body: body
            )
        )
    }

    public func updateHandicapIndex(_ index: Decimal?) async throws {
        let id = userId
        let descriptor = FetchDescriptor<LocalUser>(
            predicate: #Predicate { $0.id == id }
        )
        guard let local = try modelContext.fetch(descriptor).first else {
            throw UsersRepositoryError.profileMissing(id)
        }
        local.handicapIndex = index
        try modelContext.save()
        let update = UserUpdate(handicapIndex: index)
        let body = try SupabaseConfig.encoder.encode(update)
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .user,
                op: .update,
                externalId: id,
                body: body
            )
        )
    }
}

public enum UsersRepositoryError: Error, Sendable, Equatable {
    case profileMissing(UUID)
}
