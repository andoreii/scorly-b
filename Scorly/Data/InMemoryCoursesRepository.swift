import Foundation
import ScorlyDomain

/// Local-only courses fixture so the Round Setup screen has real
/// courses to cycle through while the supabase pipeline (phase 6) is
/// not yet wired. None of this ships to the server — supabase
/// migrations stay schema-only.
final class InMemoryCoursesRepository: CoursesRepository {
    private let courses: [Course]

    init(courses: [Course] = InMemoryCoursesRepository.seed()) {
        self.courses = courses
    }

    func fetchAll() async throws -> [Course] { courses }
    func fetch(id: UUID) async throws -> Course? { courses.first(where: { $0.id == id }) }
    func save(_: Course) async throws {}
    func update(_: Course) async throws {}
    func delete(id _: UUID) async throws {}

    // MARK: - Seed

    /// A handful of demo courses with realistic pars + tee yardages.
    /// Same shape an eventual supabase course graph would take; phase 6
    /// swaps this out for the live repository.
    static func seed() -> [Course] {
        let userId = UUID()
        return [
            buildCourse(
                userId: userId,
                name: "Pebble Ridge GC",
                location: "Monterey, CA",
                pars: [4, 5, 3, 4, 4, 5, 3, 4, 4, 4, 4, 3, 4, 5, 4, 4, 3, 5],
                teeSpecs: [
                    .init(name: "Black", rating: 74.8, slope: 138, yardage: 6912),
                    .init(name: "Blue", rating: 73.4, slope: 134, yardage: 6504),
                    .init(name: "White", rating: 71.2, slope: 128, yardage: 6128),
                    .init(name: "Red", rating: 68.9, slope: 119, yardage: 5421),
                ]
            ),
            buildCourse(
                userId: userId,
                name: "Cypress Hollow",
                location: "Carmel, CA",
                pars: [4, 4, 3, 5, 4, 4, 5, 3, 4, 4, 4, 4, 3, 5, 4, 4, 3, 4],
                teeSpecs: [
                    .init(name: "Blue", rating: 71.8, slope: 128, yardage: 6312),
                    .init(name: "White", rating: 69.6, slope: 122, yardage: 5984),
                    .init(name: "Red", rating: 67.4, slope: 116, yardage: 5410),
                ]
            ),
            buildCourse(
                userId: userId,
                name: "Linksmoor",
                location: "Half Moon Bay, CA",
                pars: [4, 5, 4, 3, 4, 4, 5, 3, 4, 4, 4, 3, 5, 4, 4, 4, 3, 5],
                teeSpecs: [
                    .init(name: "Championship", rating: 74.2, slope: 141, yardage: 6788),
                    .init(name: "Members", rating: 72.1, slope: 134, yardage: 6402),
                    .init(name: "Forward", rating: 69.5, slope: 124, yardage: 5602),
                ]
            ),
            buildCourse(
                userId: userId,
                name: "Birch Park Muni",
                location: "San Jose, CA",
                pars: [4, 4, 3, 4, 5, 3, 4, 4, 4, 4, 3, 4, 5, 4, 4, 4, 3, 4],
                teeSpecs: [
                    .init(name: "White", rating: 69.5, slope: 119, yardage: 5910),
                    .init(name: "Red", rating: 67.2, slope: 113, yardage: 5320),
                ]
            ),
        ]
    }

    private struct TeeSpec {
        let name: String
        let rating: Decimal
        let slope: Decimal
        let yardage: Int
    }

    private static func buildCourse(
        userId: UUID,
        name: String,
        location: String,
        pars: [Int],
        teeSpecs: [TeeSpec]
    ) -> Course {
        let createdAt = Date(timeIntervalSinceReferenceDate: 0)
        let holes = pars.enumerated().map { offset, par in
            Hole(
                id: UUID(),
                externalId: UUID(),
                number: offset + 1,
                par: par,
                handicapIndex: nil
            )
        }
        let tees = teeSpecs.map { spec in
            let teeHoles = (1...18).map { holeNumber in
                TeeHole(
                    id: UUID(),
                    externalId: UUID(),
                    holeNumber: holeNumber,
                    yardage: max(80, spec.yardage / 18)
                )
            }
            return Tee(
                id: UUID(),
                externalId: UUID(),
                name: spec.name,
                courseRating: spec.rating,
                slopeRating: spec.slope,
                totalYardage: spec.yardage,
                teeHoles: teeHoles
            )
        }
        return Course(
            id: UUID(),
            externalId: UUID(),
            userId: userId,
            name: name,
            location: location,
            createdAt: createdAt,
            tees: tees,
            holes: holes
        )
    }
}
