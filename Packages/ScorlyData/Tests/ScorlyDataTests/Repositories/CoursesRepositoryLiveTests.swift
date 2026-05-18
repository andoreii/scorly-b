import Foundation
import ScorlyDomain
import SwiftData
import Testing
@testable import ScorlyData

struct CoursesRepositoryLiveTests {
    @Test("save persists the full graph and fetch returns it")
    func saveGraph() async throws {
        let fixture = try Fixture()
        let teeId = UUID()
        let course = Course(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            name: "Banyan Tree",
            location: "Phuket",
            colorTheme: "Forest",
            createdAt: Date(),
            tees: [
                Tee(
                    id: teeId,
                    externalId: teeId,
                    name: "Championship",
                    courseRating: Decimal(string: "72.0"),
                    slopeRating: Decimal(string: "133"),
                    teeHoles: [
                        TeeHole(id: UUID(), externalId: UUID(), holeNumber: 1, yardage: 380),
                        TeeHole(id: UUID(), externalId: UUID(), holeNumber: 2, yardage: 415),
                    ]
                ),
            ],
            holes: [
                Hole(id: UUID(), externalId: UUID(), number: 1, par: 4),
                Hole(id: UUID(), externalId: UUID(), number: 2, par: 4),
            ]
        )
        try await fixture.repository.save(course)
        let fetched = try await fixture.repository.fetchAll()
        #expect(fetched.count == 1)
        let stored = try #require(fetched.first)
        #expect(stored.name == "Banyan Tree")
        #expect(stored.tees.count == 1)
        #expect(stored.tees.first?.teeHoles.count == 2)
        #expect(stored.holes.count == 2)
        #expect(await fixture.engine.pendingCount() == 1)
    }

    @Test("update changes course metadata and enqueues a course/update entry")
    func updateMetadata() async throws {
        let fixture = try Fixture()
        let externalId = UUID()
        let course = Course(
            id: externalId,
            externalId: externalId,
            userId: fixture.userId,
            name: "Banyan Tree",
            createdAt: Date()
        )
        try await fixture.repository.save(course)
        let renamed = Course(
            id: externalId,
            externalId: externalId,
            userId: course.userId,
            name: "Banyan Tree Golf Club",
            createdAt: course.createdAt
        )
        try await fixture.repository.update(renamed)
        let fetched = try await fixture.repository.fetchAll()
        #expect(fetched.first?.name == "Banyan Tree Golf Club")
        #expect(await fixture.engine.pendingCount() == 2)
    }

    @Test("fetchAll pulls Supabase courses into the local cache before returning")
    func fetchAllPullsRemoteCoursesIntoLocalCache() async throws {
        let fixture = try Fixture()
        let courseExternalId = UUID()
        let teeExternalId = UUID()
        let holeExternalId = UUID()
        let teeHoleExternalId = UUID()

        await fixture.remote.setPullResult(
            fullGraphPullResult(
                courseExternalId: courseExternalId,
                teeExternalId: teeExternalId,
                holeExternalId: holeExternalId,
                teeHoleExternalId: teeHoleExternalId,
                userId: fixture.userId
            )
        )

        let fetched = try await fixture.repository.fetchAll()

        #expect(fetched.count == 1)
        let course = try #require(fetched.first)
        #expect(course.externalId == courseExternalId)
        #expect(course.name == "Live Course")
        #expect(course.tees.count == 1)
        #expect(course.tees.first?.externalId == teeExternalId)
        #expect(course.tees.first?.teeHoles.first?.externalId == teeHoleExternalId)
        #expect(course.holes.first?.externalId == holeExternalId)

        let context = ModelContext(fixture.container)
        #expect(try context.fetch(FetchDescriptor<LocalCourse>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<LocalTee>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<LocalHole>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<LocalTeeHole>()).count == 1)
    }

    @Test("fetchAll imports legacy Supabase courses and applies mockup color order")
    func fetchAllImportsLegacyRowsWithMockupColors() async throws {
        let fixture = try Fixture()
        await fixture.remote.setPullResult(
            RemotePullResult(
                courses: legacyCourseRows(userId: fixture.userId),
                observedAt: Date(timeIntervalSince1970: 4_000)
            )
        )

        let fetched = try await fixture.repository.fetchAll()

        #expect(fetched.map(\.name) == [
            "First Real Course",
            "Second Real Course",
            "Third Real Course",
            "Fourth Real Course",
            "Fifth Real Course",
            "Sixth Real Course",
            "Seventh Real Course",
        ])
        #expect(fetched.map(\.colorTheme) == [
            "Sand",
            "Forest",
            "Clay",
            "Mist",
            "Rose",
            "Pine",
            "Wheat",
        ])
        #expect(fetched.first?.tees.count == 1)
        #expect(fetched.first?.tees.first?.teeHoles.count == 1)
        #expect(fetched.first?.holes.count == 1)
    }

    @Test("fetchAll forces Taiyo course variants to Rose")
    func fetchAllForcesTaiyoVariantsToRose() async throws {
        let fixture = try Fixture()
        await fixture.remote.setPullResult(
            RemotePullResult(
                courses: [
                    legacyCourseRow(id: 1, userId: fixture.userId, name: "Taiyo G.C", createdAt: 2_000),
                    legacyCourseRow(id: 2, userId: fixture.userId, name: "Another Course", createdAt: 1_000),
                ],
                observedAt: Date(timeIntervalSince1970: 3_000)
            )
        )

        let fetched = try await fixture.repository.fetchAll()

        #expect(fetched.first?.name == "Taiyo G.C")
        #expect(fetched.first?.colorTheme == "Rose")
        #expect(fetched.dropFirst().first?.colorTheme == "Forest")
    }

    @Test("fetchAll caches visible Supabase courses under the active local user")
    func fetchAllImportsVisibleRemoteRowsForActiveUser() async throws {
        let fixture = try Fixture()
        let legacyOwnerId = UUID()
        await fixture.remote.setPullResult(
            RemotePullResult(
                courses: [
                    legacyCourseRow(
                        id: 1,
                        userId: legacyOwnerId,
                        name: "Visible Legacy Course",
                        createdAt: 1_000
                    ),
                ],
                observedAt: Date(timeIntervalSince1970: 2_000)
            )
        )

        let fetched = try await fixture.repository.fetchAll()

        #expect(fetched.map(\.name) == ["Visible Legacy Course"])
        #expect(fetched.first?.userId == fixture.userId)

        let context = ModelContext(fixture.container)
        let local = try #require(try context.fetch(FetchDescriptor<LocalCourse>()).first)
        #expect(local.userId == fixture.userId)
    }

    @Test("fetchAll pulls round stats and orders courses by most played")
    func fetchAllPullsRoundStatsAndOrdersByMostPlayed() async throws {
        let fixture = try Fixture()
        await fixture.remote.setPullResult(
            RemotePullResult(
                courses: [
                    legacyCourseRow(id: 1, userId: fixture.userId, name: "Less Played", createdAt: 3_000),
                    legacyCourseRow(id: 2, userId: fixture.userId, name: "Most Played", createdAt: 2_000),
                    legacyCourseRow(id: 3, userId: fixture.userId, name: "Unplayed", createdAt: 1_000),
                ],
                rounds: [
                    roundRow(id: 1, courseId: 1, userId: fixture.userId, holesPlayed: "18", totalScore: 90),
                    roundRow(id: 2, courseId: 2, userId: fixture.userId, holesPlayed: "18", totalScore: 84),
                    roundRow(id: 3, courseId: 2, userId: fixture.userId, holesPlayed: "18", totalScore: 80),
                    roundRow(id: 4, courseId: 2, userId: fixture.userId, holesPlayed: "Front 9", totalScore: 41),
                ],
                observedAt: Date(timeIntervalSince1970: 4_000)
            )
        )

        let fetched = try await fixture.repository.fetchAll()

        #expect(fetched.map(\.name) == ["Most Played", "Less Played", "Unplayed"])
        let mostPlayed = try #require(fetched.first)
        #expect(mostPlayed.roundsPlayed == 3)
        #expect(mostPlayed.averageScore == 82)
        #expect(mostPlayed.bestScore == 80)

        let lessPlayed = try #require(fetched.dropFirst().first)
        #expect(lessPlayed.roundsPlayed == 1)
        #expect(lessPlayed.averageScore == 90)
        #expect(lessPlayed.bestScore == 90)

        let unplayed = try #require(fetched.last)
        #expect(unplayed.roundsPlayed == 0)
        #expect(unplayed.averageScore == nil)
        #expect(unplayed.bestScore == nil)
    }

    @Test("fetchAll attempts Supabase pull even before network monitor reports online")
    func fetchAllPullsBeforeNetworkMonitorWarmsUp() async throws {
        let fixture = try Fixture(initiallyOnline: false)
        await fixture.remote.setPullResult(
            RemotePullResult(
                courses: [
                    legacyCourseRow(
                        id: 1,
                        userId: fixture.userId,
                        name: "Monitor Warmup Course",
                        createdAt: 1_000
                    ),
                ],
                observedAt: Date(timeIntervalSince1970: 2_000)
            )
        )

        let fetched = try await fixture.repository.fetchAll()

        #expect(fetched.map(\.name) == ["Monitor Warmup Course"])
    }

    @Test("fetchAll only returns courses for the configured user")
    func fetchAllScopesCoursesToUser() async throws {
        let fixture = try Fixture()
        let otherUserId = UUID()
        let context = ModelContext(fixture.container)
        context.insert(
            LocalCourse(
                externalId: UUID(),
                userId: fixture.userId,
                name: "Mine",
                createdAt: Date(timeIntervalSince1970: 2_000)
            )
        )
        context.insert(
            LocalCourse(
                externalId: UUID(),
                userId: otherUserId,
                name: "Someone Else",
                createdAt: Date(timeIntervalSince1970: 3_000)
            )
        )
        try context.save()

        let fetched = try await fixture.repository.fetchAll()

        #expect(fetched.map(\.name) == ["Mine"])
    }
}
