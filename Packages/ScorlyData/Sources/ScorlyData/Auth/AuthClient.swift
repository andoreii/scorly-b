import Foundation

/// Thin protocol the `AuthService` talks to. Production wires the live
/// Supabase SDK behind `LiveSupabaseAuthClient`; tests inject `MockAuthClient`
/// and drive the state machine deterministically.
///
/// The shape mirrors the slice of `supabase.auth` v1's `AuthService.swift`
/// touched: read the current session, observe an event stream, and
/// `signUp` / `signIn` / `signOut`. Anything richer (password reset, OAuth,
/// MFA) gets added here when the corresponding feature ships — Sign in with
/// Apple is the next entry, deferred to v2.1 per the Phase D plan.
public protocol AuthClient: Sendable {
    /// The currently restored session, if any. Returns nil when no session
    /// is persisted on disk. `AuthService.init` calls this once on launch
    /// to seed `state` before the event stream takes over.
    func currentSession() async throws -> AuthSession?

    /// Hot stream of auth lifecycle events. The Supabase SDK emits an
    /// initial event reflecting the persisted session immediately; the
    /// mock matches that contract so tests don't have to special-case the
    /// boot transition.
    ///
    /// `async` because actor-isolated implementations need to read state
    /// (the persisted session) to seed the stream. Callers `await` once
    /// to grab the stream, then iterate without further hops.
    func events() async -> AsyncStream<AuthEvent>

    /// Create the account, then sign in. v1 explicitly signs in after
    /// sign-up because `signUp` alone does not always activate the session
    /// (depends on the project's email-confirmation setting). The returned
    /// session is the active one post-sign-in.
    func signUp(email: String, password: String) async throws -> AuthSession

    /// Sign in with email + password. Returns the freshly minted session.
    func signIn(email: String, password: String) async throws -> AuthSession

    /// Tear down the session locally and remotely. Subsequent
    /// `currentSession()` calls return nil and the event stream emits
    /// `.signedOut`.
    func signOut() async throws
}

/// The slice of a Supabase `Session` the rest of the app actually consumes:
/// who the user is and how to address them. The access / refresh tokens
/// stay inside the SDK — neither the UI nor the data layer ever needs to
/// touch them directly.
public struct AuthSession: Sendable, Equatable, Hashable {
    public let userId: UUID
    public let email: String?

    public init(userId: UUID, email: String? = nil) {
        self.userId = userId
        self.email = email
    }
}

/// Auth lifecycle events the service reacts to. Mirrors the v1 switch over
/// `AuthChangeEvent` collapsed to the cases v2 actually handles —
/// `signedIn`, `signedOut`, `tokenRefreshed`. `passwordRecovery` and
/// `userUpdated` get folded into `tokenRefreshed` for now since the v2.0
/// surface doesn't expose those flows; we'll split them when there's a
/// reason to.
public enum AuthEvent: Sendable, Equatable {
    case signedIn(AuthSession)
    case tokenRefreshed(AuthSession)
    case signedOut
}

/// Errors the live `AuthClient` may surface. Anything coming back from the
/// Supabase SDK is wrapped as `.underlying(message)` so callers don't have
/// to import `Auth` types to catch them. The mock raises these directly to
/// exercise error paths.
public enum AuthClientError: Error, Sendable, Equatable {
    /// The Supabase SDK threw — message carries `localizedDescription`.
    case underlying(String)
    /// The session restored from disk was missing required fields. Treated
    /// the same as "no session" — surfaces in tests, never expected to
    /// fire in production.
    case malformedSession
}
