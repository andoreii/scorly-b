import Foundation
import ScorlyDomain
import SwiftData

extension SyncEngine {
    // MARK: - Pull merging

    func mergeUsers(_ rows: [UserRow]) -> Int {
        var changed = 0
        for row in rows {
            let id = row.id
            let descriptor = FetchDescriptor<LocalUser>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                if row.createdAt > existing.createdAt {
                    existing.update(from: row)
                    changed += 1
                }
            } else {
                modelContext.insert(LocalUser(from: row))
                changed += 1
            }
        }
        return changed
    }

    func mergeCourses(_ rows: [CourseRow], localUserId: UUID?) -> Int {
        var changed = 0
        for (index, row) in rows.enumerated() {
            let externalId = row.courseExternalId
                .flatMap(UUID.init(uuidString:)) ?? LegacyExternalID.course(row.courseId)
            let userId = localUserId ?? row.userId
            let colorTheme = CourseMockupColorTheme.colorTheme(for: row, index: index)
            let descriptor = FetchDescriptor<LocalCourse>(
                predicate: #Predicate { $0.externalId == externalId }
            )
            var courseChanged = false
            if let existing = try? modelContext.fetch(descriptor).first {
                if row.createdAt > existing.createdAt
                    || existing.colorTheme != colorTheme
                    || existing.userId != userId {
                    existing.update(from: row)
                    existing.userId = userId
                    existing.colorTheme = colorTheme
                    courseChanged = true
                }
            } else {
                modelContext.insert(
                    LocalCourse(
                        serverId: row.courseId,
                        externalId: externalId,
                        userId: userId,
                        name: row.courseName,
                        location: row.location,
                        notes: row.notes,
                        colorTheme: colorTheme,
                        createdAt: row.createdAt
                    )
                )
                courseChanged = true
            }
            let teeChanges = mergeTees(row.tees ?? [], courseExternalId: externalId)
            let holeChanges = mergeHoles(row.holes ?? [], courseExternalId: externalId)
            if courseChanged || teeChanges > 0 || holeChanges > 0 {
                changed += 1
            }
        }
        return changed
    }

    func mergeRounds(_ rows: [RoundRow], localUserId: UUID?) -> Int {
        var changed = 0
        for row in rows {
            let externalId = row.roundExternalId
                .flatMap(UUID.init(uuidString:)) ?? LegacyExternalID.round(row.roundId)
            upsertRound(row, externalId: externalId, userId: localUserId ?? row.userId)
            changed += 1
        }
        return changed
    }

    func mergeGoals(_ rows: [GoalRow]) -> Int {
        var changed = 0
        for row in rows {
            guard let externalString = row.goalExternalId,
                  let externalId = UUID(uuidString: externalString)
            else { continue }
            let descriptor = FetchDescriptor<LocalGoal>(
                predicate: #Predicate { $0.externalId == externalId }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                if row.createdAt > existing.createdAt {
                    existing.title = row.title
                    existing.notes = row.notes
                    existing.kindData = row.payload
                    existing.deadline = row.deadline
                    existing.archivedAt = row.archivedAt
                    existing.createdAt = row.createdAt
                    existing.serverId = row.goalId
                    changed += 1
                }
            } else {
                modelContext.insert(
                    LocalGoal(
                        serverId: row.goalId,
                        externalId: externalId,
                        userId: row.userId,
                        title: row.title,
                        notes: row.notes,
                        kindData: row.payload,
                        createdAt: row.createdAt,
                        deadline: row.deadline,
                        archivedAt: row.archivedAt
                    )
                )
                changed += 1
            }
        }
        return changed
    }

    private func mergeTees(_ rows: [TeeRow], courseExternalId: UUID) -> Int {
        var changed = 0
        for row in rows {
            let externalId = row.teeExternalId
                .flatMap(UUID.init(uuidString:)) ?? LegacyExternalID.tee(row.teeId)
            let descriptor = FetchDescriptor<LocalTee>(
                predicate: #Predicate { $0.externalId == externalId }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.update(from: row, courseExternalId: courseExternalId)
            } else {
                modelContext.insert(
                    LocalTee(
                        serverId: row.teeId,
                        externalId: externalId,
                        courseExternalId: courseExternalId,
                        name: row.teeName,
                        courseRating: row.courseRating,
                        slopeRating: row.slopeRating,
                        totalYardage: row.yardage
                    )
                )
            }
            changed += 1
            changed += mergeTeeHoles(row.teeHoles ?? [], teeExternalId: externalId)
        }
        return changed
    }

    private func mergeHoles(_ rows: [HoleRow], courseExternalId: UUID) -> Int {
        var changed = 0
        for row in rows {
            let externalId = row.holeExternalId
                .flatMap(UUID.init(uuidString:)) ?? LegacyExternalID.hole(row.holeId)
            let descriptor = FetchDescriptor<LocalHole>(
                predicate: #Predicate { $0.externalId == externalId }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.update(from: row, courseExternalId: courseExternalId)
            } else {
                modelContext.insert(
                    LocalHole(
                        serverId: row.holeId,
                        externalId: externalId,
                        courseExternalId: courseExternalId,
                        number: row.holeNumber,
                        par: row.par,
                        handicapIndex: row.holeHandicapIndex
                    )
                )
            }
            changed += 1
        }
        return changed
    }

    private func mergeTeeHoles(_ rows: [TeeHoleRow], teeExternalId: UUID) -> Int {
        var changed = 0
        for row in rows {
            let externalId = row.teeHoleExternalId
                .flatMap(UUID.init(uuidString:)) ?? LegacyExternalID.teeHole(row.teeHoleId)
            let descriptor = FetchDescriptor<LocalTeeHole>(
                predicate: #Predicate { $0.externalId == externalId }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.update(from: row, teeExternalId: teeExternalId)
            } else {
                modelContext.insert(
                    LocalTeeHole(
                        serverId: row.teeHoleId,
                        externalId: externalId,
                        teeExternalId: teeExternalId,
                        holeNumber: row.holeNumber,
                        yardage: row.yardage
                    )
                )
            }
            changed += 1
        }
        return changed
    }

    private func upsertRound(_ row: RoundRow, externalId: UUID, userId: UUID) {
        let descriptor = FetchDescriptor<LocalRound>(
            predicate: #Predicate { $0.externalId == externalId }
        )
        let courseExternalId = localCourseExternalId(serverId: row.courseId)
            ?? LegacyExternalID.course(row.courseId)
        let teeExternalId = row.teeId.flatMap { localTeeExternalId(serverId: $0) }
            ?? row.teeId.map(LegacyExternalID.tee)
        if let existing = try? modelContext.fetch(descriptor).first {
            update(
                existing,
                from: row,
                userId: userId,
                courseExternalId: courseExternalId,
                teeExternalId: teeExternalId
            )
        } else {
            modelContext.insert(
                localRound(
                    from: row,
                    externalId: externalId,
                    userId: userId,
                    courseExternalId: courseExternalId,
                    teeExternalId: teeExternalId
                )
            )
        }
        if let holeStatRows = row.holeStats, !holeStatRows.isEmpty {
            mergeHoleStats(
                holeStatRows,
                roundExternalId: externalId,
                courseExternalId: courseExternalId
            )
        }
    }

    private func mergeHoleStats(
        _ rows: [HoleStatRow],
        roundExternalId: UUID,
        courseExternalId: UUID
    ) {
        let pars = holePars(for: courseExternalId)
        for row in rows {
            let statExternalId: UUID = row.holeStatExternalId
                .flatMap(UUID.init(uuidString:))
                ?? LegacyExternalID.holeStat(row.holeStatId)
            let par = pars[row.holeNumber] ?? 0
            let descriptor = FetchDescriptor<LocalHoleStat>(
                predicate: #Predicate { $0.externalId == statExternalId }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.par = par
                existing.strokes = row.strokes
                existing.putts = row.putts
                existing.teeShot = row.teeShot
                existing.approach = row.approach
                existing.teeClub = row.teeClub
                existing.approachClub = row.approachClub
                existing.outOfBoundsCount = row.outOfBoundsCount ?? 0
                existing.penaltyStrokes = row.penaltyStrokes ?? 0
                existing.hazardCount = row.hazardCount ?? 0
                existing.greenInReg = row.greenInReg
                existing.threePutt = row.threePutt
                existing.upAndDownSuccess = row.upAndDownSuccess
                existing.sandSaveSuccess = row.sandSaveSuccess
                existing.puttDistances = row.puttDistances
                existing.teeShotDistance = row.teeShotDistance
                existing.approachDistance = row.approachDistance
                existing.pinPosition = row.pinPosition
            } else {
                modelContext.insert(
                    LocalHoleStat(
                        serverId: row.holeStatId,
                        externalId: statExternalId,
                        roundExternalId: roundExternalId,
                        holeNumber: row.holeNumber,
                        par: par,
                        strokes: row.strokes,
                        putts: row.putts,
                        teeShot: row.teeShot,
                        approach: row.approach,
                        teeClub: row.teeClub,
                        approachClub: row.approachClub,
                        outOfBoundsCount: row.outOfBoundsCount ?? 0,
                        penaltyStrokes: row.penaltyStrokes ?? 0,
                        hazardCount: row.hazardCount ?? 0,
                        greenInReg: row.greenInReg,
                        threePutt: row.threePutt,
                        upAndDownSuccess: row.upAndDownSuccess,
                        sandSaveSuccess: row.sandSaveSuccess,
                        puttDistances: row.puttDistances,
                        teeShotDistance: row.teeShotDistance,
                        approachDistance: row.approachDistance,
                        pinPosition: row.pinPosition
                    )
                )
            }
        }
    }

    private func holePars(for courseExternalId: UUID) -> [Int: Int] {
        let descriptor = FetchDescriptor<LocalHole>(
            predicate: #Predicate { $0.courseExternalId == courseExternalId }
        )
        let holes = (try? modelContext.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0.par) })
    }

    private func update(
        _ round: LocalRound,
        from row: RoundRow,
        userId: UUID,
        courseExternalId: UUID,
        teeExternalId: UUID?
    ) {
        round.serverId = row.roundId
        round.userId = userId
        round.courseExternalId = courseExternalId
        round.teeExternalId = teeExternalId
        round.datePlayed = row.datePlayed
        round.holesPlayed = row.holesPlayed
        round.roundType = row.roundType
        round.roundFormat = row.roundFormat
        round.conditions = row.conditions
        round.temperature = row.temperature
        round.walkingVsRiding = row.walkingVsRiding
        round.startedAt = row.startedAt
        round.finishedAt = row.finishedAt
        round.mentalState = row.mentalState
        round.notes = row.notes
        round.totalScore = row.totalScore
        round.whsDifferential = row.whsDifferential
        round.createdAt = row.createdAt
        round.isDraft = false
    }

    private func localRound(
        from row: RoundRow,
        externalId: UUID,
        userId: UUID,
        courseExternalId: UUID,
        teeExternalId: UUID?
    ) -> LocalRound {
        LocalRound(
            serverId: row.roundId,
            externalId: externalId,
            userId: userId,
            courseExternalId: courseExternalId,
            teeExternalId: teeExternalId,
            datePlayed: row.datePlayed,
            holesPlayed: row.holesPlayed,
            roundType: row.roundType,
            roundFormat: row.roundFormat,
            conditions: row.conditions,
            temperature: row.temperature,
            walkingVsRiding: row.walkingVsRiding,
            startedAt: row.startedAt,
            finishedAt: row.finishedAt,
            mentalState: row.mentalState,
            notes: row.notes,
            totalScore: row.totalScore,
            whsDifferential: row.whsDifferential,
            createdAt: row.createdAt,
            isDraft: false
        )
    }

    private func localCourseExternalId(serverId: Int) -> UUID? {
        let descriptor = FetchDescriptor<LocalCourse>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return (try? modelContext.fetch(descriptor).first)?.externalId
    }

    private func localTeeExternalId(serverId: Int) -> UUID? {
        let descriptor = FetchDescriptor<LocalTee>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return (try? modelContext.fetch(descriptor).first)?.externalId
    }
}

private enum LegacyExternalID {
    static func course(_ id: Int) -> UUID {
        make(kind: "8001", id: id)
    }

    static func tee(_ id: Int) -> UUID {
        make(kind: "8002", id: id)
    }

    static func hole(_ id: Int) -> UUID {
        make(kind: "8003", id: id)
    }

    static func teeHole(_ id: Int) -> UUID {
        make(kind: "8004", id: id)
    }

    static func round(_ id: Int) -> UUID {
        make(kind: "8005", id: id)
    }

    static func holeStat(_ id: Int) -> UUID {
        make(kind: "8006", id: id)
    }

    private static func make(kind: String, id: Int) -> UUID {
        let hex = String(format: "%012llx", Int64(id))
        guard let uuid = UUID(uuidString: "00000000-0000-4000-\(kind)-\(hex)") else {
            preconditionFailure("Invalid deterministic legacy UUID")
        }
        return uuid
    }
}
