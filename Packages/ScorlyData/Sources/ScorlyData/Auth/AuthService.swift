import Foundation
import Observation
import ScorlyDomain

/// `AuthService` is the v2 port of v1's `AuthService.swift`. It owns the
/// "is the user signed in?" question for the whole app and exposes its
/// answer as an `@Observable` `state` property the SwiftUI layer (Phase J1)
/// renders directly.
///
/// Lifecycle:
/// 1. `init` enqueues a restore + observe task that
///    - reads `client.currentSession()` once to seed `state`,
///    - then drains `client.events()` forever, applying each event.
/// 2. `signUp` / `signIn` / `signOut` go through the same `client`; the
///    event stream is what actually mutates `state`, not the call sites.
///    That keeps the state machine single-sourced — there's exactly one
///    place state changes, no matter who triggered the change.
/// 3. After a successful `signIn` / `signUp`, `ensureProfile` is invoked
///    so the `users` row exists. The closure is injected by the app target
///    and typically calls `UsersRepository.upsertProfile` — keeping
///    `AuthService` from depending on `UsersRepository` directly avoids a
///    circular reference between the auth identity and the data it
///    addresses.
///
/// The class is `@MainActor` because the v1 version was, and SwiftUI views
/// observe it directly — every state read happens on the main thread.
@MainActor
@Observable
public final class AuthService {
    public private(set) var state: AuthState = .loading
    public private(set) var lastError: AuthServiceError?

    /// Convenience for SwiftUI: collapses the state enum into the boolean
    /// the loading screen + tab bar gate on.
    public var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// True until the first `currentSession` call returns. UI shows a
    /// splash while `isLoading == true` to avoid the "signed-out flash"
    /// before the persisted session restores.
    public var isLoading: Bool {
        state == .loading
    }

    /// The active user's id, if any. Conveniently nil while loading or
    /// signed out, so view-models can guard with `if let userId`.
    public var userId: UUID? {
        state.session?.userId
    }

    /// The active user's email. Settings shows it; that's the only caller.
    public var userEmail: String? {
        state.session?.email
    }

    /// First letter of the email, uppercased. v1's avatar fallback. Falls
    /// back to "?" so SwiftUI never has to render an empty string.
    public var userInitial: String {
        guard let email = userEmail, let first = email.first else { return "?" }
        return String(first).uppercased()
    }

    private let client: AuthClient
    private let ensureProfile: @Sendable (UUID) async -> Void
    /// `nonisolated` box so `deinit` can cancel without hopping back to
    /// the main actor. The box itself is `@unchecked Sendable` because it
    /// only ever stores the bootstrap task, which is set once in `init`.
    private let cancellation = TaskBox()

    /// Default ensure-profile is a no-op. Apps that wire `UsersRepository`
    /// pass a closure that calls `upsertProfile`. Tests that don't care
    /// about the side effect rely on the no-op.
    public init(
        client: AuthClient,
        ensureProfile: @escaping @Sendable (UUID) async -> Void = { _ in }
    ) {
        self.client = client
        self.ensureProfile = ensureProfile
        cancellation.task = Task { [weak self] in
            await self?.bootstrap()
        }
    }

    deinit {
        cancellation.cancel()
    }

    // MARK: - Public API (mirrors v1)

    /// Email-and-password sign-up. v1 explicitly signs in after sign-up
    /// because Supabase doesn't always return an active session from
    /// `signUp` alone (depends on the project's email-confirmation
    /// setting). The live `AuthClient` keeps that behaviour; the mock
    /// matches it for parity.
    ///
    /// On success the event stream emits `.signedIn`, which flips `state`.
    /// `ensureProfile` then runs once the new userId is known.
    public func signUp(email: String, password: String) async throws {
        lastError = nil
        do {
            let session = try await client.signUp(email: email, password: password)
            await ensureProfile(session.userId)
        } catch {
            lastError = .signUpFailed(error.localizedDescription)
            throw error
        }
    }

    public func signIn(email: String, password: String) async throws {
        lastError = nil
        do {
            let session = try await client.signIn(email: email, password: password)
            await ensureProfile(session.userId)
        } catch {
            lastError = .signInFailed(error.localizedDescription)
            throw error
        }
    }

    public func signOut() async throws {
        lastError = nil
        do {
            try await client.signOut()
        } catch {
            lastError = .signOutFailed(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Future: Sign in with Apple

    // Plan locks Apple Sign-In to v2.1 (paid-developer-account-gated).
    // The slot lives here so the next iteration drops in alongside the
    // existing email/password flow with no surrounding refactor.

    // MARK: - Lifecycle internals

    private func bootstrap() async {
        // Phase 1: restore. A throw means the persisted session is gone or
        // unreadable; fall back to .signedOut and continue to Phase 2 so
        // a future `signIn` still flows through the same code path.
        do {
            if let session = try await client.currentSession() {
                state = .signedIn(session)
            } else {
                state = .signedOut
            }
        } catch {
            lastError = .sessionRestoreFailed(error.localizedDescription)
            state = .signedOut
        }

        // Phase 2: observe. The stream is hot; the first event the live
        // SDK emits is the persisted session, so applying it is a no-op
        // when state is already correct from Phase 1. The mock matches
        // that contract.
        let stream = await client.events()
        for await event in stream {
            apply(event)
            if Task.isCancelled { break }
        }
    }

    private func apply(_ event: AuthEvent) {
        switch event {
        case let .signedIn(session), let .tokenRefreshed(session):
            state = .signedIn(session)
        case .signedOut:
            state = .signedOut
        }
    }
}

/// Nonisolated holder for the bootstrap task so `deinit` can cancel it
/// without bouncing through `@MainActor`. Set once in `init`, cancelled
/// once in `deinit` — no concurrent mutation, hence `@unchecked Sendable`.
private final class TaskBox: @unchecked Sendable {
    var task: Task<Void, Never>?
    func cancel() {
        task?.cancel()
    }
}

/// State machine the rest of the app reads. `.loading` is the boot phase
/// before `currentSession()` returns; `.signedOut` covers both "never
/// signed in" and "signed out by the user / server"; `.signedIn` carries
/// the active session.
public enum AuthState: Sendable, Equatable {
    case loading
    case signedOut
    case signedIn(AuthSession)

    public var session: AuthSession? {
        if case let .signedIn(session) = self { return session }
        return nil
    }
}

/// Surfaced via `lastError` so the UI can show a banner without callers
/// having to plumb thrown errors through view-model layers. Cases mirror
/// the entry points; `.sessionRestoreFailed` covers the boot failure that
/// has no caller to throw to.
public enum AuthServiceError: Error, Sendable, Equatable {
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case sessionRestoreFailed(String)

    public var message: String {
        switch self {
        case let .signInFailed(message),
             let .signUpFailed(message),
             let .signOutFailed(message),
             let .sessionRestoreFailed(message):
            return message
        }
    }
}

// MARK: - User profile bridging

/// Helper the app target uses when wiring `AuthService` to the live
/// `UsersRepository`. The repository contract owns the upsert; this
/// closure adapts it to the `(UUID) async -> Void` shape `AuthService`
/// asks for.
///
/// Lives here (rather than in the repository) because it's a wiring
/// helper, not part of the repository's contract — moving it would force
/// `UsersRepository` to know about `AuthService`, which is the dependency
/// direction the architecture explicitly forbids.
public enum AuthProfileBridge {
    public static func ensureProfile(
        repository: UsersRepository,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) -> @Sendable (UUID) async -> Void {
        { userId in
            do {
                if try await repository.fetchProfile() == nil {
                    let profile = User(
                        id: userId,
                        handicapIndex: nil,
                        createdAt: clock()
                    )
                    try await repository.upsertProfile(profile)
                }
            } catch {
                // Swallow — the next foreground sync pull will reconcile
                // the row from the server if the local insert lost. The
                // app target wires `ErrorReporter.capture(error)` here in
                // Phase E.
            }
        }
    }
}
