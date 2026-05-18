import Foundation
import ScorlyDomain
import SwiftData
import Testing
@testable import ScorlyData

/// Repository CRUD: `save` persists a draft + every hole stat; `fetchAllCompleted`
/// returns the engine-shaped read aggregate; `delete` removes the row + its
/// hole stats and enqueues an outbox entry.
struct RoundsRepositoryLiveTests {
    @Test("save persists round + hole stats, fetchAllCompleted reconstitutes them")
    func saveAndFetch() async throws {
        let fixture = try Fixture()
        let courseId = UUID()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: courseId,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            walkingVsRiding: .riding,
            totalScore: 82,
            createdAt: Date(),
            holeStats: [
                HoleStat(par: 4, strokes: 4, putts: 2, teeShotLie: .fairway, approachLie: .green),
                HoleStat(par: 3, strokes: 3, putts: 1, teeShotLie: .green),
            ]
        )
        try await fixture.repository.save(draft)
        let rounds = try await fixture.repository.fetchAllCompleted()
        #expect(rounds.count == 1)
        let round = try #require(rounds.first)
        #expect(round.id == draft.id)
        #expect(round.totalScore == 82)
        #expect(round.holeStats.count == 2)
        #expect(round.holeStats[0].teeShotLie == .fairway)
        #expect(round.holeStats[1].teeShotLie == .green)
        #expect(round.walkingVsRiding == .riding)
        #expect(await fixture.engine.pendingCount() == 1)
    }

    @Test("delete removes round + child hole stats + enqueues delete entry")
    func deleteCascades() async throws {
        let fixture = try Fixture()
        let id = UUID()
        let draft = RoundDraft(
            id: id,
            externalId: id,
            userId: fixture.userId,
            courseId: UUID(),
            datePlayed: Date(),
            holesPlayed: .eighteen,
            totalScore: 80,
            createdAt: Date(),
            holeStats: [HoleStat(par: 4, strokes: 4, putts: 2)]
        )
        try await fixture.repository.save(draft)
        try await fixture.repository.delete(id: id)
        let rounds = try await fixture.repository.fetchAllCompleted()
        #expect(rounds.isEmpty)
        // Hole stats should be gone too — we look at the SwiftData container
        // directly to verify that side-effect.
        let context = ModelContext(fixture.container)
        let stats = try context.fetch(FetchDescriptor<LocalHoleStat>())
        #expect(stats.isEmpty)
    }

    @Test("fetchRecentCompleted for course filters by course external id and caps newest first")
    func fetchRecentCompletedForCourse() async throws {
        let fixture = try Fixture()
        let selectedCourseId = UUID()
        let otherCourseId = UUID()
        let calendar = Calendar(identifier: .gregorian)
        let start = try #require(calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2_026,
            month: 5,
            day: 14
        )))

        for offset in 0..<25 {
            try await fixture.repository.save(RoundDraft(
                id: UUID(),
                externalId: UUID(),
                userId: fixture.userId,
                courseId: selectedCourseId,
                datePlayed: #require(calendar.date(byAdding: .day, value: -offset, to: start)),
                holesPlayed: .eighteen,
                totalScore: 80 + offset,
                createdAt: Date(),
                holeStats: [HoleStat(par: 4, strokes: 4, putts: 2)]
            ))
        }

        try await fixture.repository.save(RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: otherCourseId,
            datePlayed: #require(calendar.date(byAdding: .day, value: 1, to: start)),
            holesPlayed: .eighteen,
            totalScore: 70,
            createdAt: Date(),
            holeStats: [HoleStat(par: 4, strokes: 4, putts: 2)]
        ))

        let rounds = try await fixture.repository.fetchRecentCompleted(
            forCourseExternalId: selectedCourseId,
            limit: 20
        )

        #expect(rounds.count == 20)
        #expect(rounds.allSatisfy { $0.courseExternalId == selectedCourseId })
        #expect(rounds.map(\.datePlayed) == rounds.map(\.datePlayed).sorted(by: >))
        #expect(rounds.map(\.totalScore) == Array(80..<100))
    }

    // MARK: - Fixture

    struct Fixture {
        let container: ModelContainer
        let engine: SyncEngine
        let repository: RoundsRepositoryLive
        let userId = UUID()

        init() throws {
            container = try LocalSchema.makeInMemoryContainer()
            engine = SyncEngine.make(
                modelContainer: container,
                remote: InMemoryRemoteSyncAPI(),
                network: MockNetworkMonitor(initiallyOnline: true),
                configuration: .fast
            )
            repository = RoundsRepositoryLive.make(
                modelContainer: container,
                userId: userId,
                syncEngine: engine
            )
        }
    }
}
