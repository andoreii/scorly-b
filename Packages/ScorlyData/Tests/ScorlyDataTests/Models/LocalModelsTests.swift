import Foundation
import SwiftData
import Testing
@testable import ScorlyData

/// Pins `init(from row:)` / `update(from row:)` behavior for the @Model types.
struct LocalModelsTests {
    @Test("LocalUser init+update from UserRow round-trips scalar fields")
    func localUserFromRow() {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let row = UserRow(id: id, handicapIndex: Decimal(string: "12.4"), createdAt: now)

        let local = LocalUser(from: row)
        #expect(local.id == id)
        #expect(local.handicapIndex == Decimal(string: "12.4"))
        #expect(local.createdAt == now)

        let later = Date(timeIntervalSince1970: 1_700_999_999)
        let updated = UserRow(id: id, handicapIndex: nil, createdAt: later)
        local.update(from: updated)
        #expect(local.handicapIndex == nil)
        #expect(local.createdAt == later)
    }

    @Test("LocalCourse init returns nil for legacy rows missing course_external_id")
    func localCourseLegacyRowReturnsNil() {
        let row = CourseRow(
            courseId: 99,
            userId: UUID(),
            courseName: "Legacy",
            location: nil,
            notes: nil,
            colorTheme: nil,
            courseExternalId: nil, // Pre-Phase-C row.
            createdAt: Date(),
            tees: nil,
            holes: nil
        )
        #expect(LocalCourse(from: row) == nil)
    }

    @Test("LocalCourse init + update preserves identity by externalId")
    func localCourseRoundTrip() throws {
        let externalId = UUID()
        let row = CourseRow(
            courseId: 12,
            userId: UUID(),
            courseName: "Banyan Tree",
            location: "Phuket",
            notes: nil,
            colorTheme: "Forest",
            courseExternalId: externalId.uuidString,
            createdAt: Date(timeIntervalSince1970: 1),
            tees: nil,
            holes: nil
        )
        let local = try #require(LocalCourse(from: row))
        #expect(local.externalId == externalId)
        #expect(local.serverId == 12)
        #expect(local.name == "Banyan Tree")

        let renamed = CourseRow(
            courseId: 12,
            userId: row.userId,
            courseName: "Banyan Tree GC",
            location: "Phuket",
            notes: "renamed",
            colorTheme: "Forest",
            courseExternalId: externalId.uuidString,
            createdAt: Date(timeIntervalSince1970: 2),
            tees: nil,
            holes: nil
        )
        local.update(from: renamed)
        #expect(local.name == "Banyan Tree GC")
        #expect(local.notes == "renamed")
    }

    @Test("LocalSchema in-memory container registers every @Model")
    func localSchemaContainerBoots() throws {
        let container = try LocalSchema.makeInMemoryContainer()
        let context = ModelContext(container)
        // Insert one of each persistable type to verify schema registration.
        context.insert(LocalUser(id: UUID(), createdAt: Date()))
        context.insert(
            LocalCourse(externalId: UUID(), userId: UUID(), name: "C", createdAt: Date())
        )
        context.insert(
            LocalRound(
                externalId: UUID(),
                userId: UUID(),
                courseExternalId: UUID(),
                datePlayed: Date(),
                holesPlayed: "18",
                createdAt: Date()
            )
        )
        context.insert(
            LocalGoal(
                externalId: UUID(),
                userId: UUID(),
                title: "Break 85",
                kindData: Data("{}".utf8),
                createdAt: Date()
            )
        )
        try context.save()

        let users = try context.fetch(FetchDescriptor<LocalUser>())
        let courses = try context.fetch(FetchDescriptor<LocalCourse>())
        let rounds = try context.fetch(FetchDescriptor<LocalRound>())
        let goals = try context.fetch(FetchDescriptor<LocalGoal>())
        #expect(users.count == 1)
        #expect(courses.count == 1)
        #expect(rounds.count == 1)
        #expect(goals.count == 1)
    }
}
