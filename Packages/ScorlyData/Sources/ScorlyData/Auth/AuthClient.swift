import Foundation

/// Protocol the `AuthService` talks to. Production wires the live Supabase
/// SDK behind `LiveSupabaseAuthClient`; tests inject `MockAuthClient`.
public protocol AuthClient: Sendable {
    /// Restored session, if any. Called once on launch to seed `state`.
    func currentSession() async throws -> AuthSession?

    /// Hot stream of auth lifecycle events; emits an initial event for the
    /// persisted session immediately.
    func events() async -> AsyncStream<AuthEvent>

    /// Create the account, then sign in (signUp alone doesn't always
    /// activate a session depending on email-confirmation settings).
    func signUp(email: String, password: String) async throws -> AuthSession

    /// Sign in with email + password. Returns the freshly minted session.
    func signIn(email: String, password: String) async throws -> AuthSession

    /// Tear down the session locally and remotely.
    func signOut() async throws
}

/// The slice of a Supabase `Session` the rest of the app consumes: who the
/// user is and how to address them. Tokens stay inside the SDK.
public struct AuthSession: Sendable, Equatable, Hashable {
    public let userId: UUID
    public let email: String?

    public init(userId: UUID, email: String? = nil) {
        self.userId = userId
        self.email = email
    }
}

/// Auth lifecycle events the service reacts to.
public enum AuthEvent: Sendable, Equatable {
    case signedIn(AuthSession)
    case tokenRefreshed(AuthSession)
    case signedOut
}

/// Errors the live `AuthClient` may surface, wrapped so callers don't need
/// to import `Auth` types to catch them.
public enum AuthClientError: Error, Sendable, Equatable {
    /// The Supabase SDK threw — message carries `localizedDescription`.
    case underlying(String)
    /// Persisted session was missing required fields; treated as "no session".
    case malformedSession
}
