import Foundation

/// A round paused mid-play, stored locally so the player can resume from Home.
/// `entriesPayload` is an opaque JSON blob owned by the feature layer.
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
    /// Opaque feature-owned encoding of editable setup metadata.
    public var setupPayload: Data?

    public init(
        id: UUID,
        userId: UUID,
        courseExternalId: UUID,
        teeExternalId: UUID?,
        holesPlayed: HolesPlayed,
        startedAt: Date,
        updatedAt: Date,
        holeIdx: Int,
        entriesPayload: Data,
        setupPayload: Data? = nil
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
        self.setupPayload = setupPayload
    }
}
