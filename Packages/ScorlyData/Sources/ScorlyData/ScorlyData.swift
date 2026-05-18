import Foundation
import ScorlyDomain

/// Data layer for Scorly v2.
///
/// Hosts the Supabase client (Phase D-wired), SwiftData models,
/// repositories, and the offline-first sync engine. May import
/// `ScorlyDomain` and Supabase; never imports UIKit/SwiftUI. Architecture
/// is enforced by Harmonize tests in Phase G.
///
/// **Public surface** (re-exported below for ergonomic imports):
/// - `SupabaseConfig` — URL, key, JSON coders.
/// - `LocalSchema` — model registration + in-memory factory for tests.
/// - `OutboxEntry` / `OutboxAggregate` / `OutboxOperation` — queue model.
/// - `SyncEngine` + supporting `SyncConfiguration`, `PendingOutbox`,
///   `RemoteSyncAPI`, `NetworkMonitor`.
/// - `*RepositoryLive` — concrete implementations of Domain protocols.
public enum ScorlyData {}
