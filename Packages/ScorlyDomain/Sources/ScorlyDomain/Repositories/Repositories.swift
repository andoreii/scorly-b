import Foundation

// Repository protocols live in Domain so features can program against
// abstractions and use in-memory fakes in tests. Concrete implementations
// live in `ScorlyData`.
//
// Conventions:
// - All operations are `async throws`.
// - Reads return Domain value types (already round-tripped from rows).
// - Writes accept Domain value types; the data layer is responsible for
//   converting to `*Insert`/`*Update` payloads, persisting to SwiftData,
//   and enqueuing an outbox entry within the same transaction.
// - `delete` is by domain `id` (UUID), never by serial DB key — the data
//   layer translates as needed.
//
// Sendable: every protocol is `Sendable` so repositories can be passed
// across actor boundaries (the SyncEngine owns its own actor; features
// run on the main actor).

public protocol UsersRepository: Sendable {
    /// Current signed-in user's profile, or nil if no row exists yet.
    func fetchProfile() async throws -> User?
    /// Insert the row immediately after sign-up. Idempotent on `id`.
    func upsertProfile(_ user: User) async throws
    /// WHS handicap is recomputed locally; the server stores the displayed value.
    func updateHandicapIndex(_ index: Decimal?) async throws
}

public protocol CoursesRepository: Sendable {
    func fetchAll() async throws -> [Course]
    func fetch(id: UUID) async throws -> Course?
    func save(_ course: Course) async throws
    func update(_ course: Course) async throws
    func delete(id: UUID) async throws
}

public protocol RoundsRepository: Sendable {
    /// All rounds, in domain (read) shape — what goals + insights consume.
    func fetchAllCompleted() async throws -> [CompletedRound]
    /// Most recent `limit` completed rounds, newest first.
    func fetchRecent(limit: Int) async throws -> [CompletedRound]
    /// Most recent completed rounds for a specific course, newest first.
    func fetchRecentCompleted(forCourseExternalId courseExternalId: UUID, limit: Int) async throws -> [CompletedRound]
    /// Pull the most recent `limit` rounds from Supabase and upsert them
    /// into the local SwiftData cache. Idempotent; never enqueues outbox entries.
    func refreshFromRemote(limit: Int) async throws
    /// Persist a finished round. The implementation derives `CompletedRound`
    /// state from the draft for downstream consumers.
    func save(_ round: RoundDraft) async throws
    func update(_ round: RoundDraft) async throws
    func delete(id: UUID) async throws
    /// Read the user's single in-progress round draft, or nil if none.
    /// Local-only — never round-trips through Supabase.
    func fetchInProgressDraft() async throws -> InProgressRoundDraft?
    /// Insert or replace the in-progress draft for the current user.
    /// One draft per user; existing draft is overwritten.
    func upsertInProgressDraft(_ draft: InProgressRoundDraft) async throws
    /// Remove the in-progress draft. No-op if nothing is stored.
    func deleteInProgressDraft() async throws
}

public protocol GoalsRepository: Sendable {
    /// All non-archived goals.
    func fetchActive() async throws -> [Goal]
    /// All goals, archived or not.
    func fetchAll() async throws -> [Goal]
    func save(_ goal: Goal) async throws
    func update(_ goal: Goal) async throws
    /// Soft-delete: stamp `archivedAt`. Hard delete is `delete(id:)`.
    func archive(id: UUID, at date: Date) async throws
    func delete(id: UUID) async throws
}
