import Foundation
import ScorlyDomain
import SwiftData
import Testing
@testable import ScorlyData

extension RoundsRepositoryLiveTests {
    @Test("save writes OB tee detail and automatic penalty strokes locally and to the outbox")
    func saveWritesAutomaticOBPenalty() async throws {
        let fixture = try Fixture()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: UUID(),
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            totalScore: 6,
            createdAt: Date(),
            holeStats: [
                HoleStat(
                    par: 4,
                    strokes: 6,
                    putts: 2,
                    penaltyEvents: [
                        PenaltyEvent(kind: .outOfBounds, direction: .right, phase: .tee),
                    ]
                ),
            ]
        )
        try await fixture.repository.save(draft)

        let context = ModelContext(fixture.container)
        let saved = try #require(try context.fetch(FetchDescriptor<LocalHoleStat>()).first)
        #expect(saved.teeShot == "Out Right")
        #expect(saved.penaltyStrokes == 1)

        let entries = try context.fetch(FetchDescriptor<OutboxEntry>())
        let roundEntry = try #require(entries.first { $0.aggregate == OutboxAggregate.round.rawValue })
        let body = try SupabaseConfig.decoder.decode(RoundOutboxBody.self, from: roundEntry.payload)
        let payload = try #require(body.holeStats.first)
        #expect(payload.teeShot == "Out Right")
        #expect(payload.penaltyStrokes == 1)
    }

    @Test("save writes playable approach misses without Out prefix")
    func saveWritesPlayableApproachMisses() async throws {
        let fixture = try Fixture()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: UUID(),
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            totalScore: 5,
            createdAt: Date(),
            holeStats: [
                HoleStat(
                    par: 4,
                    strokes: 5,
                    putts: 2,
                    teeShotLie: .fairway,
                    approachLie: .recoveryShort
                ),
            ]
        )
        try await fixture.repository.save(draft)

        let context = ModelContext(fixture.container)
        let saved = try #require(try context.fetch(FetchDescriptor<LocalHoleStat>()).first)
        #expect(saved.approach == "Short")
    }

    @Test("save writes par-3 input only to approach fields")
    func saveWritesPar3OnlyToApproachFields() async throws {
        let fixture = try Fixture()
        let draft = RoundDraft(
            id: UUID(),
            externalId: UUID(),
            userId: fixture.userId,
            courseId: UUID(),
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: .eighteen,
            totalScore: 3,
            createdAt: Date(),
            holeStats: [
                HoleStat(
                    par: 3,
                    strokes: 3,
                    putts: 2,
                    teeShotLie: .green,
                    approachDistance: 170,
                    approachClub: "7 iron"
                ),
            ]
        )
        try await fixture.repository.save(draft)

        let context = ModelContext(fixture.container)
        let saved = try #require(try context.fetch(FetchDescriptor<LocalHoleStat>()).first)
        #expect(saved.teeShot == nil)
        #expect(saved.teeClub == nil)
        #expect(saved.approach == "Green")
        #expect(saved.approachClub == "7 iron")

        let entries = try context.fetch(FetchDescriptor<OutboxEntry>())
        let roundEntry = try #require(entries.first { $0.aggregate == OutboxAggregate.round.rawValue })
        let body = try SupabaseConfig.decoder.decode(RoundOutboxBody.self, from: roundEntry.payload)
        let payload = try #require(body.holeStats.first)
        #expect(payload.teeShot == nil)
        #expect(payload.teeClub == nil)
        #expect(payload.approach == "Green")
        #expect(payload.approachClub == "7 iron")
    }
}
