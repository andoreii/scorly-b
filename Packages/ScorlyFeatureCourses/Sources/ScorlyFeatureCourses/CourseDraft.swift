import Foundation
import ScorlyDomain

/// Editable form state for the Course Editor screen. `existing` is nil
/// for "+ NEW COURSE", in which case `commit` synthesises a standard
/// par-72 18-hole graph so the course is usable right away.
public struct CourseDraft: Equatable {
    public var name: String
    public var location: String
    public var notes: String
    public let existing: Course?

    public init(name: String, location: String, notes: String, existing: Course? = nil) {
        self.name = name
        self.location = location
        self.notes = notes
        self.existing = existing
    }

    public static func new() -> CourseDraft {
        CourseDraft(name: "", location: "", notes: "", existing: nil)
    }

    public static func from(_ course: Course) -> CourseDraft {
        CourseDraft(
            name: course.name,
            location: course.location ?? "",
            notes: course.notes ?? "",
            existing: course
        )
    }

    public var isEditingExisting: Bool {
        existing != nil
    }

    /// True when name has at least one non-blank character — the only
    /// hard requirement to save.
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Builds the `Course` to persist; new drafts get a generated par-72 graph and default tee.
    public func commit(userId: UUID, now: Date = .now) -> Course {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationOrNil = trimmedLocation.isEmpty ? nil : trimmedLocation
        let notesOrNil = trimmedNotes.isEmpty ? nil : trimmedNotes

        if let existing {
            return Course(
                id: existing.id,
                externalId: existing.externalId,
                userId: existing.userId,
                name: trimmedName,
                location: locationOrNil,
                notes: notesOrNil,
                colorTheme: existing.colorTheme,
                createdAt: existing.createdAt,
                roundsPlayed: existing.roundsPlayed,
                averageScore: existing.averageScore,
                bestScore: existing.bestScore,
                tees: existing.tees,
                holes: existing.holes
            )
        }
        let externalId = UUID()
        let holes = Self.standardHoles()
        let tee = Self.standardTee()
        return Course(
            id: externalId,
            externalId: externalId,
            userId: userId,
            name: trimmedName,
            location: locationOrNil,
            notes: notesOrNil,
            colorTheme: nil,
            createdAt: now,
            roundsPlayed: 0,
            averageScore: nil,
            bestScore: nil,
            tees: [tee],
            holes: holes
        )
    }

    /// Par-72 sequence: 4 par-5s, 10 par-4s, 4 par-3s, split evenly across both nines.
    private static let standardPars: [Int] = [
        4, 5, 4, 3, 4, 4, 3, 4, 5,
        4, 4, 3, 5, 4, 4, 3, 4, 5,
    ]

    private static func standardHoles() -> [Hole] {
        standardPars.enumerated().map { index, par in
            let id = UUID()
            return Hole(
                id: id,
                externalId: id,
                number: index + 1,
                par: par,
                handicapIndex: nil
            )
        }
    }

    /// Default tee with rough per-hole yardage estimates; refined later via course sync.
    private static func standardTee() -> Tee {
        let teeId = UUID()
        let teeHoles: [TeeHole] = standardPars.enumerated().map { index, par in
            let yardage: Int
            switch par {
            case 3: yardage = 165
            case 5: yardage = 510
            default: yardage = 380
            }
            let id = UUID()
            return TeeHole(
                id: id,
                externalId: id,
                holeNumber: index + 1,
                yardage: yardage
            )
        }
        return Tee(
            id: teeId,
            externalId: teeId,
            name: "White",
            courseRating: nil,
            slopeRating: nil,
            totalYardage: teeHoles.reduce(0) { $0 + $1.yardage },
            teeHoles: teeHoles
        )
    }
}
