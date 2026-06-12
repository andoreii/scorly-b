import Foundation
import Supabase

/// Production `AuthClient`. Wraps `supabase-swift`'s `SupabaseClient.auth`
/// and translates Supabase types into `AuthSession` / `AuthEvent`.
public struct LiveSupabaseAuthClient: AuthClient {
    private let supabase: SupabaseClient

    public init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    public func currentSession() async throws -> AuthSession? {
        do {
            let session = try await supabase.auth.session
            return AuthSession(session: session)
        } catch {
            // No persisted session is "logged out", not an error.
            if isSessionMissing(error) {
                return nil
            }
            throw AuthClientError.underlying(error.localizedDescription)
        }
    }

    public func events() -> AsyncStream<AuthEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await(event, session) in supabase.auth.authStateChanges {
                    let mapped = mapEvent(event, session: session)
                    if let mapped {
                        continuation.yield(mapped)
                    }
                    if Task.isCancelled { break }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func signUp(email: String, password: String) async throws -> AuthSession {
        do {
            _ = try await supabase.auth.signUp(email: email, password: password)
        } catch {
            throw AuthClientError.underlying(error.localizedDescription)
        }
        // signUp alone may not start a session if email confirmation is required.
        return try await signIn(email: email, password: password)
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            return AuthSession(session: session)
        } catch {
            throw AuthClientError.underlying(error.localizedDescription)
        }
    }

    public func signOut() async throws {
        do {
            try await supabase.auth.signOut()
        } catch {
            throw AuthClientError.underlying(error.localizedDescription)
        }
    }

    // MARK: - Mapping

    /// Collapse the SDK's event enum into the three cases we react to;
    /// anything else maps to `tokenRefreshed` (if a session exists) or `signedOut`.
    private func mapEvent(
        _ event: AuthChangeEvent,
        session: Session?
    ) -> AuthEvent? {
        switch event {
        case .signedIn, .initialSession:
            guard let session else { return .signedOut }
            return .signedIn(AuthSession(session: session))
        case .signedOut:
            return .signedOut
        case .tokenRefreshed, .userUpdated, .passwordRecovery, .mfaChallengeVerified:
            guard let session else { return nil }
            return .tokenRefreshed(AuthSession(session: session))
        case .userDeleted:
            return .signedOut
        @unknown default:
            return nil
        }
    }

    /// String-match since the SDK has spelled "no session" differently
    /// across versions; resilient to SDK bumps.
    private func isSessionMissing(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("sessionmissing")
            || description.contains("session_not_found")
            || description.contains("session not found")
            || description.contains("no current session")
    }
}

private extension AuthSession {
    init(session: Session) {
        self.init(userId: session.user.id, email: session.user.email)
    }
}
