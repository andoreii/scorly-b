import Foundation
import ScorlyDomain

/// Encodes setup-only metadata for a local in-progress round draft.
///
/// Course, tee, and holes-played remain authoritative in the draft's typed
/// fields because play can change the active hole slice independently.
public enum RoundSetupSnapshotCodec {
    public static func encode(_ form: RoundSetupForm) -> Data {
        let snapshot = Snapshot(
            datePlayed: form.datePlayed,
            roundType: form.roundType,
            roundFormat: form.roundFormat,
            conditionsRawValue: form.conditions.rawValue,
            temperature: form.temperature,
            walkingVsRiding: form.walkingVsRiding,
            mentalState: form.mentalState,
            notes: form.notes,
            players: form.players.map(PlayerSnapshot.init)
        )
        return (try? JSONEncoder().encode(snapshot)) ?? Data()
    }

    public static func decode(_ data: Data) -> RoundSetupForm? {
        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return nil
        }
        return RoundSetupForm(
            datePlayed: snapshot.datePlayed,
            roundType: snapshot.roundType,
            roundFormat: snapshot.roundFormat,
            conditions: Conditions(rawValue: snapshot.conditionsRawValue),
            temperature: snapshot.temperature,
            walkingVsRiding: snapshot.walkingVsRiding,
            mentalState: snapshot.mentalState,
            notes: snapshot.notes,
            players: snapshot.players.map(\.formPlayer)
        )
    }

    private struct Snapshot: Codable {
        let datePlayed: Date
        let roundType: RoundType?
        let roundFormat: RoundFormat?
        let conditionsRawValue: Int
        let temperature: Int
        let walkingVsRiding: WalkingVsRiding?
        let mentalState: Int
        let notes: String
        let players: [PlayerSnapshot]
    }

    private struct PlayerSnapshot: Codable {
        let id: UUID
        let name: String
        let handicap: Decimal?

        init(_ player: RoundSetupForm.Player) {
            id = player.id
            name = player.name
            handicap = player.handicap
        }

        var formPlayer: RoundSetupForm.Player {
            RoundSetupForm.Player(id: id, name: name, handicap: handicap)
        }
    }
}
