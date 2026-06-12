import Foundation

/// Deterministic in-memory `AuthClient` for tests + previews. Tests stage
/// the next `currentSession` answer, configure errors to throw on demand,
/// and observe the event stream as `signIn` / `signUp` / `signOut` flips
/// the internal state.
///
/// An actor so it lives off the main actor, like the live SDK.
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
            // Mirror the live SDK: emit the persisted session first.
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

    /// Stage the error the next `currentSession` call should raise (one-shot).
    public func setNextRestoreError(_ error: Error) {
        nextRestoreError = error
    }

    /// Push a `tokenRefreshed` event without going through sign-in.
    public func emitTokenRefresh(session refreshed: AuthSession) {
        session = refreshed
        broadcast(.tokenRefreshed(refreshed))
    }

    /// Externally trigger a `signedOut` event (e.g. server invalidates session).
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
