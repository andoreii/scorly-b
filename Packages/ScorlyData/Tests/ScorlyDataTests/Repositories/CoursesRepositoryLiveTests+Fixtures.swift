import Foundation
import SwiftData
@testable import ScorlyData

extension CoursesRepositoryLiveTests {
    func fullGraphPullResult(
        courseExternalId: UUID,
        teeExternalId: UUID,
        holeExternalId: UUID,
        teeHoleExternalId: UUID,
        userId: UUID
    ) -> RemotePullResult {
        RemotePullResult(
            courses: [
                CourseRow(
                    courseId: 10,
                    userId: userId,
                    courseName: "Live Course",
                    location: "Okinawa",
                    notes: "Pulled from Supabase",
                    colorTheme: "Pine",
                    courseExternalId: courseExternalId.uuidString,
                    createdAt: Date(timeIntervalSince1970: 2_000),
                    tees: [
                        TeeRow(
                            teeId: 20,
                            courseId: 10,
                            teeName: "Blue",
                            courseRating: Decimal(string: "71.4"),
                            slopeRating: Decimal(128),
                            yardage: 6_450,
                            teeExternalId: teeExternalId.uuidString,
                            teeHoles: [
                                TeeHoleRow(
                                    teeHoleId: 40,
                                    teeId: 20,
                                    holeNumber: 1,
                                    yardage: 390,
                                    teeHoleExternalId: teeHoleExternalId.uuidString
                                ),
                            ]
                        ),
                    ],
                    holes: [
                        HoleRow(
                            holeId: 30,
                            courseId: 10,
                            holeNumber: 1,
                            par: 4,
                            holeHandicapIndex: 7,
                            holeExternalId: holeExternalId.uuidString
                        ),
                    ]
                ),
            ],
            observedAt: Date(timeIntervalSince1970: 3_000)
        )
    }

    func legacyCourseRows(userId: UUID) -> [CourseRow] {
        [
            legacyCourseRow(id: 1, userId: userId, name: "First Real Course", createdAt: 3_000, includeChildren: true),
            legacyCourseRow(id: 2, userId: userId, name: "Second Real Course", createdAt: 2_000),
            legacyCourseRow(id: 3, userId: userId, name: "Third Real Course", createdAt: 1_000),
            legacyCourseRow(id: 4, userId: userId, name: "Fourth Real Course", createdAt: 900),
            legacyCourseRow(id: 5, userId: userId, name: "Fifth Real Course", createdAt: 800),
            legacyCourseRow(id: 6, userId: userId, name: "Sixth Real Course", createdAt: 700),
            legacyCourseRow(id: 7, userId: userId, name: "Seventh Real Course", createdAt: 600),
        ]
    }

    func legacyCourseRow(
        id: Int,
        userId: UUID,
        name: String,
        createdAt: TimeInterval,
        includeChildren: Bool = false
    ) -> CourseRow {
        CourseRow(
            courseId: id,
            userId: userId,
            courseName: name,
            location: nil,
            notes: nil,
            colorTheme: "OldColor",
            courseExternalId: nil,
            createdAt: Date(timeIntervalSince1970: createdAt),
            tees: includeChildren ? legacyTees(courseId: id) : nil,
            holes: includeChildren ? legacyHoles(courseId: id) : nil
        )
    }

    func roundRow(
        id: Int,
        courseId: Int,
        userId: UUID,
        holesPlayed: String,
        totalScore: Int?
    ) -> RoundRow {
        RoundRow(
            roundId: id,
            userId: userId,
            courseId: courseId,
            teeId: nil,
            datePlayed: Date(timeIntervalSince1970: TimeInterval(2_000 + id)),
            holesPlayed: holesPlayed,
            roundType: nil,
            roundFormat: nil,
            conditions: nil,
            temperature: nil,
            walkingVsRiding: nil,
            startedAt: nil,
            finishedAt: nil,
            mentalState: nil,
            roundExternalId: nil,
            notes: nil,
            whsDifferential: nil,
            totalScore: totalScore,
            createdAt: Date(timeIntervalSince1970: TimeInterval(3_000 + id)),
            holeStats: nil,
            players: nil
        )
    }

    func legacyTees(courseId: Int) -> [TeeRow] {
        [
            TeeRow(
                teeId: courseId * 10 + 1,
                courseId: courseId,
                teeName: "White",
                courseRating: Decimal(string: "70.1"),
                slopeRating: Decimal(120),
                yardage: nil,
                teeExternalId: nil,
                teeHoles: [
                    TeeHoleRow(
                        teeHoleId: courseId * 100 + 11,
                        teeId: courseId * 10 + 1,
                        holeNumber: 1,
                        yardage: 350,
                        teeHoleExternalId: nil
                    ),
                ]
            ),
        ]
    }

    func legacyHoles(courseId: Int) -> [HoleRow] {
        [
            HoleRow(
                holeId: courseId * 100 + 1,
                courseId: courseId,
                holeNumber: 1,
                par: 4,
                holeHandicapIndex: nil,
                holeExternalId: nil
            ),
        ]
    }

    struct Fixture {
        let container: ModelContainer
        let remote: InMemoryRemoteSyncAPI
        let engine: SyncEngine
        let repository: CoursesRepositoryLive
        let userId = UUID()

        init(initiallyOnline: Bool = true) throws {
            container = try LocalSchema.makeInMemoryContainer()
            remote = InMemoryRemoteSyncAPI()
            engine = SyncEngine.make(
                modelContainer: container,
                remote: remote,
                network: MockNetworkMonitor(initiallyOnline: initiallyOnline),
                configuration: .fast
            )
            repository = CoursesRepositoryLive.make(
                modelContainer: container,
                userId: userId,
                syncEngine: engine
            )
        }
    }
}
