import Foundation
import ScorlyDomain

/// Empty in-memory placeholder. Phase 6 swaps this for the real
/// `RoundsRepositoryLive` once Supabase migrations are applied and the
/// sync engine is wired into `ScorlyApp.init`. Until then the Home /
/// History screens render their "no rounds yet" empty states.
final class InMemoryRoundsRepository: RoundsRepository, @unchecked Sendable {
    private let rounds: [CompletedRound]
    private var draft: InProgressRoundDraft?

    init(rounds: [CompletedRound] = []) {
        self.rounds = rounds
    }

    func fetchAllCompleted() async throws -> [CompletedRound] {
        rounds
    }

    func fetchRecent(limit: Int) async throws -> [CompletedRound] {
        Array(rounds.prefix(limit))
    }

    func fetchRecentCompleted(forCourseExternalId: UUID, limit: Int) async throws -> [CompletedRound] {
        Array(rounds.filter { $0.courseExternalId == forCourseExternalId }.prefix(limit))
    }

    func refreshFromRemote(limit _: Int) async throws {}
    func save(_: RoundDraft) async throws {}
    func update(_: RoundDraft) async throws {}
    func delete(id _: UUID) async throws {}
    func fetchInProgressDraft() async throws -> InProgressRoundDraft? {
        draft
    }

    func upsertInProgressDraft(_ draft: InProgressRoundDraft) async throws {
        self.draft = draft
    }

    func deleteInProgressDraft() async throws {
        draft = nil
    }

    func bestScoresByCourse(filter: AggregateRoundFilter) async throws -> [UUID: Int] {
        var best: [UUID: Int] = [:]
        for round in rounds where filter.includes(round) {
            guard let courseId = round.courseExternalId else { continue }
            if let prev = best[courseId] {
                best[courseId] = min(prev, round.totalScore)
            } else {
                best[courseId] = round.totalScore
            }
        }
        return best
    }
}
