import Foundation
import Observation
import ScorlyDomain

/// Owns the "is the user signed in?" question for the whole app, exposed as
/// an `@Observable` `state` property SwiftUI renders directly.
///
/// `state` is only ever mutated by the event stream (from `client.events()`),
/// never directly by `signUp`/`signIn`/`signOut`, so there's one source of
/// truth regardless of who triggered the change. `ensureProfile` runs after a
/// successful sign-in/up to create the `users` row; it's injected so
/// `AuthService` doesn't depend on `UsersRepository` directly.
@MainActor
@Observable
public final class AuthService {
    public private(set) var state: AuthState = .loading
    public private(set) var lastError: AuthServiceError?

    /// Collapses `state` into the boolean the loading screen + tab bar gate on.
    public var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// True until the first `currentSession` call returns; avoids a
    /// signed-out flash before the persisted session restores.
    public var isLoading: Bool {
        state == .loading
    }

    /// Active user's id, nil while loading or signed out.
    public var userId: UUID? {
        state.session?.userId
    }

    /// Active user's email, shown in settings.
    public var userEmail: String? {
        state.session?.email
    }

    /// First letter of the email, uppercased, falling back to "?".
    public var userInitial: String {
        guard let email = userEmail, let first = email.first else { return "?" }
        return String(first).uppercased()
    }

    private let client: AuthClient
    private let ensureProfile: @Sendable (UUID) async -> Void
    /// Nonisolated box so `deinit` can cancel the bootstrap task without
    /// hopping back to the main actor.
    private let cancellation = TaskBox()

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

    // MARK: - Public API

    /// On success the event stream emits `.signedIn`, flipping `state`, then
    /// `ensureProfile` runs with the new userId.
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

    // MARK: - Lifecycle internals

    private func bootstrap() async {
        // A throw means the persisted session is gone/unreadable; fall back
        // to signedOut so a future signIn still works.
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

        // Stream is hot; its first event reflects the persisted session, so
        // applying it is a no-op if state above is already correct.
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
/// without bouncing through `@MainActor`.
private final class TaskBox: @unchecked Sendable {
    var task: Task<Void, Never>?
    func cancel() {
        task?.cancel()
    }
}

/// State machine the rest of the app reads.
public enum AuthState: Sendable, Equatable {
    case loading
    case signedOut
    case signedIn(AuthSession)

    public var session: AuthSession? {
        if case let .signedIn(session) = self { return session }
        return nil
    }
}

/// Surfaced via `lastError` so the UI can show a banner without plumbing
/// thrown errors through view-models.
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

/// Adapts `UsersRepository.upsertProfile` to the `(UUID) async -> Void`
/// shape `AuthService` expects, without `UsersRepository` depending on `AuthService`.
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
                // Swallow — next foreground sync will reconcile if this insert lost.
            }
        }
    }
}
