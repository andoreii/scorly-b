import Foundation
import ScorlyDomain
import SwiftData
import Testing
@testable import ScorlyData

struct HoleStatsBackfillTests {
    @Test("backfill upserts complete rows so missing remote hole stats are recreated")
    func backfillRecreatesMissingRemoteHoleStats() async throws {
        let fixture = try Fixture()
        let roundExternalId = UUID()
        let statExternalId = UUID()
        let context = ModelContext(fixture.container)
        context.insert(makeRound(externalId: roundExternalId, userId: fixture.userId))
        context.insert(makeStat(externalId: statExternalId, roundExternalId: roundExternalId))
        try context.save()

        let count = try await fixture.repository.backfillHoleStatsToCloud()
        let batches = await fixture.remote.batches

        #expect(count == 1)
        #expect(batches.count == 1)
        let row = try #require(batches.first?.first)
        #expect(row.roundId == 91)
        #expect(row.holeNumber == 1)
        #expect(row.holeStatExternalId == statExternalId.uuidString)
        #expect(row.teeClub == "Driver")
        #expect(row.approachClub == "7 iron")
        #expect(row.puttDistances == [18, 3])
        #expect(row.teeShotDistance == 240)
        #expect(row.approachDistance == 160)
        #expect(row.pinPosition == "Middle")
        #expect(row.penaltyStrokes == 1)
    }

    private func makeRound(externalId: UUID, userId: UUID) -> LocalRound {
        LocalRound(
            serverId: 91,
            externalId: externalId,
            userId: userId,
            courseExternalId: UUID(),
            teeExternalId: nil,
            datePlayed: Date(timeIntervalSince1970: 1_700_000_000),
            holesPlayed: HolesPlayed.eighteen.rawValue,
            roundType: nil,
            roundFormat: nil,
            conditions: nil,
            temperature: nil,
            walkingVsRiding: nil,
            startedAt: nil,
            finishedAt: nil,
            mentalState: nil,
            notes: nil,
            totalScore: 4,
            whsDifferential: nil,
            createdAt: Date(),
            isDraft: false
        )
    }

    private func makeStat(externalId: UUID, roundExternalId: UUID) -> LocalHoleStat {
        LocalHoleStat(
            externalId: externalId,
            roundExternalId: roundExternalId,
            holeNumber: 1,
            par: 4,
            strokes: 4,
            putts: 2,
            teeShot: "Fairway",
            approach: "Green",
            teeClub: "Driver",
            approachClub: "7 iron",
            greenInReg: true,
            threePutt: false,
            puttDistances: [18, 3],
            teeShotDistance: 240,
            approachDistance: 160,
            pinPosition: "Middle",
            penaltyEventsJSON: """
            [{"kind":"outOfBounds","direction":"left","phase":"tee"}]
            """
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let remote: RecordingHoleStatsRemoteAPI
        let repository: RoundsRepositoryLive
        let userId = UUID()

        init() throws {
            container = try LocalSchema.makeInMemoryContainer()
            remote = RecordingHoleStatsRemoteAPI()
            let engine = SyncEngine.make(
                modelContainer: container,
                remote: InMemoryRemoteSyncAPI(),
                network: MockNetworkMonitor(initiallyOnline: true),
                configuration: .fast
            )
            repository = RoundsRepositoryLive.make(
                modelContainer: container,
                userId: userId,
                syncEngine: engine,
                holeStatsRemote: remote
            )
        }
    }
}

private actor RecordingHoleStatsRemoteAPI: HoleStatsRemoteAPI {
    private(set) var batches: [[HoleStatInsert]] = []

    func upsert(_ rows: [HoleStatInsert]) async throws {
        batches.append(rows)
    }
}
