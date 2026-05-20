import Foundation
import ScorlyDomain

/// Editable form state for the Course Editor screen. Owns the three
/// fields the editor exposes (name, location, notes); everything else
/// on the underlying `Course` is preserved verbatim on save.
///
/// `existing` is the source-of-truth `Course` we're editing; nil for
/// "+ NEW COURSE". When nil, `commit` synthesises a standard par-72
/// 18-hole course graph so a freshly-added course is immediately
/// usable in Round Setup without a follow-up edit pass.
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

    public var isEditingExisting: Bool { existing != nil }

    /// True when name has at least one non-blank character — the only
    /// hard requirement to save.
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Build the `Course` to persist. For new drafts, generates a
    /// standard par-72 18-hole graph (4 par-5s, 10 par-4s, 4 par-3s,
    /// canonical hole order) plus one default tee ("White") with
    /// approximate yardages. The user can refine via remote sync once
    /// the real course is set up upstream.
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

    /// Canonical par sequence for a generated par-72 18-hole course.
    /// Mix is the textbook 4 × par-5, 10 × par-4, 4 × par-3 ordered so
    /// par-3s and par-5s are spread across both nines.
    private static let standardPars: [Int] = [
        4, 5, 4, 3, 4, 4, 3, 4, 5, // front 9 — total 36
        4, 4, 3, 5, 4, 4, 3, 4, 5, // back 9  — total 36
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

    /// One default tee with rough yardage estimate per hole (par × 100
    /// for the par-3-light average). Real yardages come in via course
    /// sync when the course is connected to a curated record.
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
