import Foundation
import SwiftData

/// Operation queued for the SyncEngine to push to Supabase. Every
/// repository write enqueues one of these inside the same SwiftData
/// transaction as the local insert/update — so either both land or neither
/// does, and a crash mid-write is recoverable on next launch.
///
/// Idempotency: `externalId` is the same UUID stored on the local record.
/// The server-side UNIQUE constraint on `*_external_id` lets us safely
/// retry without duplicates.
@Model
public final class OutboxEntry {
    @Attribute(.unique)
    public var id: UUID
    /// Aggregate type — drives which Supabase table the entry targets.
    public var aggregate: String
    /// Operation kind — insert / update / delete / archive.
    public var op: String
    /// Domain external ID of the affected record.
    public var externalId: UUID
    /// JSON-encoded payload. Shape depends on (aggregate, op):
    /// inserts carry the `*Insert`, updates carry the `*Update`, deletes
    /// carry just the externalId (so the payload is empty `{}`).
    public var payload: Data
    /// Number of failed push attempts. Drives exponential backoff.
    public var attempts: Int
    /// Last error string, for diagnostics. nil on success / pending.
    public var lastError: String?
    /// When this entry was first enqueued. Drives FIFO ordering on drain.
    public var createdAt: Date
    /// Earliest time the SyncEngine will retry. nil means "now".
    public var nextAttemptAt: Date?

    // swiftlint:disable:next function_default_parameter_at_end
    public init(
        id: UUID = UUID(),
        aggregate: OutboxAggregate,
        op: OutboxOperation,
        externalId: UUID,
        payload: Data,
        attempts: Int = 0,
        lastError: String? = nil,
        createdAt: Date = Date(),
        nextAttemptAt: Date? = nil
    ) {
        self.id = id
        self.aggregate = aggregate.rawValue
        self.op = op.rawValue
        self.externalId = externalId
        self.payload = payload
        self.attempts = attempts
        self.lastError = lastError
        self.createdAt = createdAt
        self.nextAttemptAt = nextAttemptAt
    }

    public var aggregateKind: OutboxAggregate? {
        OutboxAggregate(rawValue: aggregate)
    }

    public var operationKind: OutboxOperation? {
        OutboxOperation(rawValue: op)
    }
}

public enum OutboxAggregate: String, Sendable, CaseIterable, Codable {
    case user
    case course
    case tee
    case hole
    case teeHole
    case round
    case holeStat
    case goal
}

public enum OutboxOperation: String, Sendable, CaseIterable, Codable {
    case insert
    case update
    case delete
    /// Soft-delete: stamp `archived_at` on the row. Distinct from `delete`
    /// because hard deletes cascade in Postgres; archives don't.
    case archive
}
