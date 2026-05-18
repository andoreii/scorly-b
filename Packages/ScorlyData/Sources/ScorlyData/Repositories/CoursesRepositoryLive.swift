import Foundation
import ScorlyDomain
import SwiftData

/// SwiftData-backed `CoursesRepository`. A `Course` owns its tees and holes,
/// so persisting one writes the whole graph and enqueues a single
/// course-shaped outbox entry. The Supabase live impl will fan that out
/// into nested inserts in Phase D.
public actor CoursesRepositoryLive: CoursesRepository {
    nonisolated let userId: UUID
    nonisolated let syncEngine: SyncEngine
    nonisolated let modelContainer: ModelContainer
    private let modelContext: ModelContext

    public static func make(
        modelContainer: ModelContainer,
        userId: UUID,
        syncEngine: SyncEngine
    ) -> CoursesRepositoryLive {
        CoursesRepositoryLive(
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

    public func fetchAll() async throws -> [Course] {
        _ = try await syncEngine.pullAndReconcile(
            forceNetworkAttempt: true,
            localCourseUserId: userId
        )
        let userId = userId
        let descriptor = FetchDescriptor<LocalCourse>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let locals = try modelContext.fetch(descriptor)
        return locals
            .map(buildCourse)
            .sortedByMostPlayedStable()
    }

    public func fetch(id: UUID) async throws -> Course? {
        _ = try await syncEngine.pullAndReconcile(
            forceNetworkAttempt: true,
            localCourseUserId: userId
        )
        return try findLocal(externalId: id).map(buildCourse)
    }

    public func save(_ course: Course) async throws {
        let local = LocalCourse(
            externalId: course.externalId,
            userId: course.userId,
            name: course.name,
            location: course.location,
            notes: course.notes,
            colorTheme: course.colorTheme,
            createdAt: course.createdAt
        )
        modelContext.insert(local)
        insertChildren(of: course)
        try modelContext.save()
        let insert = CourseInsert(
            userId: course.userId,
            courseName: course.name,
            location: course.location,
            notes: course.notes,
            colorTheme: course.colorTheme,
            courseExternalId: course.externalId.uuidString
        )
        let body = try Self.encoder.encode(insert)
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .course,
                op: .insert,
                externalId: course.externalId,
                body: body
            )
        )
    }

    public func update(_ course: Course) async throws {
        guard let local = try findLocal(externalId: course.externalId) else {
            throw CoursesRepositoryError.notFound(course.externalId)
        }
        local.name = course.name
        local.location = course.location
        local.notes = course.notes
        local.colorTheme = course.colorTheme
        try modelContext.save()
        let update = CourseUpdate(
            courseName: course.name,
            location: course.location,
            notes: course.notes,
            colorTheme: course.colorTheme
        )
        let body = try Self.encoder.encode(update)
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .course,
                op: .update,
                externalId: course.externalId,
                body: body
            )
        )
    }

    public func delete(id: UUID) async throws {
        guard let local = try findLocal(externalId: id) else {
            throw CoursesRepositoryError.notFound(id)
        }
        modelContext.delete(local)
        // Children cascade via the externalId references being orphaned —
        // a future cleanup pass collects them on next pull. The DB's
        // ON DELETE CASCADE handles the server side.
        try modelContext.save()
        try await syncEngine.enqueue(
            PendingOutbox(
                aggregate: .course,
                op: .delete,
                externalId: id,
                body: Data("{}".utf8)
            )
        )
    }

    // MARK: - Internals

    private func findLocal(externalId: UUID) throws -> LocalCourse? {
        let userId = userId
        let descriptor = FetchDescriptor<LocalCourse>(
            predicate: #Predicate { $0.externalId == externalId && $0.userId == userId }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func insertChildren(of course: Course) {
        for tee in course.tees {
            let teeLocal = LocalTee(
                externalId: tee.externalId,
                courseExternalId: course.externalId,
                name: tee.name,
                courseRating: tee.courseRating,
                slopeRating: tee.slopeRating,
                totalYardage: tee.totalYardage
            )
            modelContext.insert(teeLocal)
            for teeHole in tee.teeHoles {
                modelContext.insert(
                    LocalTeeHole(
                        externalId: teeHole.externalId,
                        teeExternalId: tee.externalId,
                        holeNumber: teeHole.holeNumber,
                        yardage: teeHole.yardage
                    )
                )
            }
        }
        for hole in course.holes {
            modelContext.insert(
                LocalHole(
                    externalId: hole.externalId,
                    courseExternalId: course.externalId,
                    number: hole.number,
                    par: hole.par,
                    handicapIndex: hole.handicapIndex
                )
            )
        }
    }

    private func buildCourse(from local: LocalCourse) -> Course {
        let courseExternalId = local.externalId
        let teesDescriptor = FetchDescriptor<LocalTee>(
            predicate: #Predicate { $0.courseExternalId == courseExternalId }
        )
        let holesDescriptor = FetchDescriptor<LocalHole>(
            predicate: #Predicate { $0.courseExternalId == courseExternalId },
            sortBy: [SortDescriptor(\.number, order: .forward)]
        )
        let tees = (try? modelContext.fetch(teesDescriptor)) ?? []
        let holes = (try? modelContext.fetch(holesDescriptor)) ?? []
        let stats = courseStats(courseExternalId: courseExternalId)
        return Course(
            id: local.externalId,
            externalId: local.externalId,
            userId: local.userId,
            name: local.name,
            location: local.location,
            notes: local.notes,
            colorTheme: local.colorTheme,
            createdAt: local.createdAt,
            roundsPlayed: stats.roundsPlayed,
            averageScore: stats.averageScore,
            bestScore: stats.bestScore,
            tees: tees.map(buildTee),
            holes: holes.map { hole in
                Hole(
                    id: hole.externalId,
                    externalId: hole.externalId,
                    number: hole.number,
                    par: hole.par,
                    handicapIndex: hole.handicapIndex
                )
            }
        )
    }

    private func courseStats(courseExternalId: UUID) -> CourseStats {
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate {
                $0.courseExternalId == courseExternalId && $0.isDraft == false
            }
        )
        let rounds = (try? modelContext.fetch(descriptor)) ?? []
        let fullRoundScores = rounds.compactMap { round -> Int? in
            guard round.holesPlayed == "18" else { return nil }
            if let totalScore = round.totalScore {
                return totalScore
            }
            let stats = fetchHoleStats(for: round.externalId)
            guard !stats.isEmpty else { return nil }
            return stats.reduce(0) { $0 + $1.strokes }
        }
        let averageScore = fullRoundScores.isEmpty
            ? nil
            : fullRoundScores.reduce(0, +) / fullRoundScores.count
        return CourseStats(
            roundsPlayed: rounds.count,
            averageScore: averageScore,
            bestScore: fullRoundScores.min()
        )
    }

    private func fetchHoleStats(for roundExternalId: UUID) -> [LocalHoleStat] {
        let descriptor = FetchDescriptor<LocalHoleStat>(
            predicate: #Predicate { $0.roundExternalId == roundExternalId }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func buildTee(from local: LocalTee) -> Tee {
        let teeExternalId = local.externalId
        let teeHolesDescriptor = FetchDescriptor<LocalTeeHole>(
            predicate: #Predicate { $0.teeExternalId == teeExternalId },
            sortBy: [SortDescriptor(\.holeNumber, order: .forward)]
        )
        let teeHoles = (try? modelContext.fetch(teeHolesDescriptor)) ?? []
        return Tee(
            id: local.externalId,
            externalId: local.externalId,
            name: local.name,
            courseRating: local.courseRating,
            slopeRating: local.slopeRating,
            totalYardage: local.totalYardage,
            teeHoles: teeHoles.map { teeHole in
                TeeHole(
                    id: teeHole.externalId,
                    externalId: teeHole.externalId,
                    holeNumber: teeHole.holeNumber,
                    yardage: teeHole.yardage
                )
            }
        )
    }

    static let encoder = SupabaseConfig.encoder
}

private struct CourseStats {
    let roundsPlayed: Int
    let averageScore: Int?
    let bestScore: Int?
}

private extension [Course] {
    func sortedByMostPlayedStable() -> [Course] {
        enumerated()
            .sorted { lhs, rhs in
                if lhs.element.roundsPlayed != rhs.element.roundsPlayed {
                    return lhs.element.roundsPlayed > rhs.element.roundsPlayed
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

public enum CoursesRepositoryError: Error, Sendable, Equatable {
    case notFound(UUID)
}
