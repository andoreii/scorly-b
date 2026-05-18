import Foundation

/// Deterministic in-memory `AuthClient` for tests + previews. Tests stage
/// the next `currentSession` answer, configure errors to throw on demand,
/// and observe the event stream as `signIn` / `signUp` / `signOut` flips
/// the internal state.
///
/// Why an actor: the v1 `AuthService` was `@MainActor`-isolated and the v2
/// service stays `@MainActor`. Putting the mock on its own actor keeps the
/// "client lives off the main actor" boundary realistic — the live SDK
/// runs its callbacks off-main, so tests should too.
public actor MockAuthClient: AuthClient {
    public private(set) var session: AuthSession?

    private var continuations: [UUID: AsyncStream<AuthEvent>.Continuation] = [:]
    private var nextSignInError: Error?
    private var nextSignUpError: Error?
    private var nextSignOutError: Error?
    private var nextRestoreError: Error?

    public init(initialSession: AuthSession? = nil) {
        session = initialSession
    }

    // MARK: - AuthClient

    public func currentSession() async throws -> AuthSession? {
        if let error = nextRestoreError {
            nextRestoreError = nil
            throw error
        }
        return session
    }

    public func events() -> AsyncStream<AuthEvent> {
        let initial = session
        return AsyncStream { continuation in
            let id = UUID()
            // Mirror the live SDK: emit an initial event reflecting the
            // persisted session before subscribers see any deltas.
            if let initial {
                continuation.yield(.signedIn(initial))
            } else {
                continuation.yield(.signedOut)
            }
            Task { self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    public func signUp(email: String, password: String) async throws -> AuthSession {
        if let error = nextSignUpError {
            nextSignUpError = nil
            throw error
        }
        let new = AuthSession(userId: UUID(), email: email)
        session = new
        broadcast(.signedIn(new))
        // v1 calls signIn explicitly after signUp. Mirror that — the live
        // SDK observation already covers it because both paths go through
        // the same `signIn` code path on the server side.
        _ = password // unused in the mock; signature parity with the real client.
        return new
    }

    public func signIn(email: String, password _: String) async throws -> AuthSession {
        if let error = nextSignInError {
            nextSignInError = nil
            throw error
        }
        let new = AuthSession(userId: session?.userId ?? UUID(), email: email)
        session = new
        broadcast(.signedIn(new))
        return new
    }

    public func signOut() async throws {
        if let error = nextSignOutError {
            nextSignOutError = nil
            throw error
        }
        session = nil
        broadcast(.signedOut)
    }

    // MARK: - Test driving

    /// Stage the error the next `signIn` call should raise (one-shot).
    public func setNextSignInError(_ error: Error) {
        nextSignInError = error
    }

    /// Stage the error the next `signUp` call should raise (one-shot).
    public func setNextSignUpError(_ error: Error) {
        nextSignUpError = error
    }

    /// Stage the error the next `signOut` call should raise (one-shot).
    public func setNextSignOutError(_ error: Error) {
        nextSignOutError = error
    }

    /// Stage the error the next `currentSession` call should raise
    /// (one-shot). Lets a test exercise the "session restore failed →
    /// drop to signedOut" path without modeling Supabase internals.
    public func setNextRestoreError(_ error: Error) {
        nextRestoreError = error
    }

    /// Push a `tokenRefreshed` event without going through sign-in. The
    /// live SDK fires this when the access token rotates; the v2 service
    /// treats it as "session is still good, update bookkeeping".
    public func emitTokenRefresh(session refreshed: AuthSession) {
        session = refreshed
        broadcast(.tokenRefreshed(refreshed))
    }

    /// Externally trigger a `signedOut` event. Models the case where the
    /// server invalidates the session out from under us.
    public func emitExternalSignOut() {
        session = nil
        broadcast(.signedOut)
    }

    // MARK: - Subscriber bookkeeping

    private func register(
        id: UUID,
        continuation: AsyncStream<AuthEvent>.Continuation
    ) {
        continuations[id] = continuation
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func broadcast(_ event: AuthEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
}
