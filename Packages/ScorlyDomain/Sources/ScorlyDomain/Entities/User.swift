import Foundation

/// Authenticated app user — mirrors the `users` table.
///
/// The `id` is the same UUID Supabase auth issues, so the data layer can
/// look up an auth-bound user without an extra round trip.
public struct User: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let handicapIndex: Decimal?
    public let createdAt: Date

    public init(id: UUID, handicapIndex: Decimal? = nil, createdAt: Date) {
        self.id = id
        self.handicapIndex = handicapIndex
        self.createdAt = createdAt
    }
}
