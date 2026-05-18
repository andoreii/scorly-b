import Foundation
import Supabase

/// Production `AuthClient`. Wraps `supabase-swift`'s `SupabaseClient.auth`
/// and translates between Supabase types and the v2 `AuthSession` /
/// `AuthEvent` value types `AuthService` consumes.
///
/// All work happens on whatever queue the Supabase SDK chose — the only
/// `@MainActor` boundary in the auth stack is `AuthService` itself.
public struct LiveSupabaseAuthClient: AuthClient {
    private let supabase: SupabaseClient

    /// Default initializer wires the singleton Supabase client the app
    /// holds (constructed from `SupabaseConfig` in `ScorlyApp`). Tests
    /// don't construct this — they use `MockAuthClient`.
    public init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    public func currentSession() async throws -> AuthSession? {
        do {
            let session = try await supabase.auth.session
            return AuthSession(session: session)
        } catch {
            // The SDK throws `.sessionMissing` when there's no persisted
            // session. Treat that as "logged out" rather than an error so
            // first-launch UX doesn't surface a spurious banner.
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
        // v1 explicitly signs in after sign-up — the project may require
        // email confirmation, in which case `signUp` does not start an
        // active session. Mirror that behaviour exactly.
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

    /// Collapse the SDK's richer event enum into the three the v2 service
    /// reacts to. Anything else (`userUpdated`, `passwordRecovery`,
    /// `mfaChallengeVerified`, `initialSession`) is reported through the
    /// nearest equivalent — `tokenRefreshed` if a session is present,
    /// `signedOut` if not — so the state machine never sees a "no-op"
    /// event it has to special-case.
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

    /// The Supabase SDK has changed how it spells "no session" across
    /// versions — sometimes `AuthError.sessionMissing`, sometimes
    /// `.sessionNotFound`. String-match is uglier than a typed catch but
    /// resilient across SDK bumps and harmless because the only consumer
    /// is "swallow vs rethrow".
    private func isSessionMissing(_ error: Error) -> Bool {
        let description = String(describing: error).lowercased()
        return description.contains("sessionmissing")
            || description.contains("session_not_found")
            || description.contains("session not found")
            || description.contains("no current session")
    }
}

private extension AuthSession {
    /// Convert the SDK's `Session` into the v2 value type. The userId is
    /// the only field downstream code actually depends on; the email is
    /// surfaced for UI display (settings, avatar fallback).
    init(session: Session) {
        self.init(userId: session.user.id, email: session.user.email)
    }
}
