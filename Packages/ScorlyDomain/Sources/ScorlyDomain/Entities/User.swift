import Foundation

/// Authenticated app user, mirrors the `users` table. `id` matches the
/// Supabase auth UUID.
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
