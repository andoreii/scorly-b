import Foundation

// Protocols live in Domain so features can use in-memory fakes in tests;
// ScorlyData provides the SwiftData + outbox-backed implementations.

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
    /// Pulls recent rounds from Supabase into the local cache; never enqueues outbox entries.
    func refreshFromRemote(limit: Int) async throws -> Int
    func save(_ round: RoundDraft) async throws
    func update(_ round: RoundDraft) async throws
    func delete(id: UUID) async throws
    /// The user's single in-progress draft, local-only and never synced.
    func fetchInProgressDraft() async throws -> InProgressRoundDraft?
    /// One draft per user; replaces any existing draft.
    func upsertInProgressDraft(_ draft: InProgressRoundDraft) async throws
    func deleteInProgressDraft() async throws
    /// Lowest `totalScore` per course among rounds matching `filter`.
    func bestScoresByCourse(filter: AggregateRoundFilter) async throws -> [UUID: Int]
    /// Backfills per-hole detail for rows written before those columns existed.
    func backfillHoleStatsToCloud() async throws -> Int
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
