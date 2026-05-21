import Foundation

/// A round paused mid-play, stored locally so the player can resume from
/// Home. `entriesPayload` is an opaque JSON blob (`[HoleEntry]` encoded
/// by the feature layer) — Domain doesn't know the live-play shape, so
/// this struct intentionally stays UI-agnostic.
///
/// Local-only by design: never enters the outbox, never pushed to
/// Supabase. Filing the round (via `RoundsRepository.save`) is what makes
/// it visible upstream.
public struct InProgressRoundDraft: Sendable, Equatable {
    public let id: UUID
    public let userId: UUID
    public let courseExternalId: UUID
    public let teeExternalId: UUID?
    public let holesPlayed: HolesPlayed
    public let startedAt: Date
    public var updatedAt: Date
    public var holeIdx: Int
    public var entriesPayload: Data

    public init(
        id: UUID,
        userId: UUID,
        courseExternalId: UUID,
        teeExternalId: UUID?,
        holesPlayed: HolesPlayed,
        startedAt: Date,
        updatedAt: Date,
        holeIdx: Int,
        entriesPayload: Data
    ) {
        self.id = id
        self.userId = userId
        self.courseExternalId = courseExternalId
        self.teeExternalId = teeExternalId
        self.holesPlayed = holesPlayed
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.holeIdx = holeIdx
        self.entriesPayload = entriesPayload
    }
}
