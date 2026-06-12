import Foundation
import ScorlyDomain
import Testing
@testable import ScorlyData

/// Behavioural coverage for the auth state machine, driven by a deterministic mock client.
struct AuthServiceTests {
    // MARK: - Bootstrap

    @Test("Boot with no persisted session settles in .signedOut")
    @MainActor
    func bootSignedOut() async {
        let client = MockAuthClient()
        let service = AuthService(client: client)
        await service.waitForBootstrapTimeout()
        #expect(service.state == .signedOut)
        #expect(service.isLoading == false)
        #expect(service.isSignedIn == false)
        #expect(service.userId == nil)
    }

    @Test("Boot with persisted session restores .signedIn(session)")
    @MainActor
    func bootSignedIn() async {
        let session = AuthSession(userId: UUID(), email: "andrei@example.com")
        let client = MockAuthClient(initialSession: session)
        let service = AuthService(client: client)
        await service.waitForBootstrapTimeout()
        #expect(service.isSignedIn == true)
        #expect(service.userId == session.userId)
        #expect(service.userEmail == session.email)
        #expect(service.userInitial == "A")
    }

    @Test("currentSession() throwing falls back to .signedOut, records lastError")
    @MainActor
    func bootRestoreFailure() async {
        let client = MockAuthClient()
        await client.setNextRestoreError(SampleError.boom)
        let service = AuthService(client: client)
        await service.waitForBootstrapTimeout()
        #expect(service.state == .signedOut)
        if case .sessionRestoreFailed = service.lastError {
            // pass
        } else {
            Issue.record("Expected .sessionRestoreFailed, got \(String(describing: service.lastError))")
        }
    }

    // MARK: - Sign in / sign up / sign out

    @Test("signIn flips state to .signedIn and triggers ensureProfile once")
    @MainActor
    func signInWiresProfile() async throws {
        let client = MockAuthClient()
        let recorder = CallRecorder()
        let service = AuthService(client: client) { userId in
            await recorder.record(userId)
        }
        await service.waitForBootstrapTimeout()

        try await service.signIn(email: "andrei@example.com", password: "swordfish")
        await service.waitForEvent(timeout: .milliseconds(500))

        #expect(service.isSignedIn == true)
        #expect(service.userEmail == "andrei@example.com")
        let calls = await recorder.calls
        #expect(calls.count == 1)
        #expect(calls.first == service.userId)
    }

    @Test("signUp flips state to .signedIn and triggers ensureProfile once")
    @MainActor
    func signUpWiresProfile() async throws {
        let client = MockAuthClient()
        let recorder = CallRecorder()
        let service = AuthService(client: client) { userId in
            await recorder.record(userId)
        }
        await service.waitForBootstrapTimeout()

        try await service.signUp(email: "new@example.com", password: "pw")
        await service.waitForEvent(timeout: .milliseconds(500))

        #expect(service.isSignedIn == true)
        #expect(service.userEmail == "new@example.com")
        let calls = await recorder.calls
        #expect(calls.count == 1)
    }

    @Test("signIn error sets lastError and rethrows; state stays .signedOut")
    @MainActor
    func signInError() async {
        let client = MockAuthClient()
        await client.setNextSignInError(SampleError.boom)
        let service = AuthService(client: client)
        await service.waitForBootstrapTimeout()

        do {
            try await service.signIn(email: "x@y.z", password: "pw")
            Issue.record("expected throw")
        } catch {
            // pass
        }
        #expect(service.state == .signedOut)
        if case .signInFailed = service.lastError {
            // pass
        } else {
            Issue.record("Expected .signInFailed, got \(String(describing: service.lastError))")
        }
    }

    @Test("signOut flips state to .signedOut")
    @MainActor
    func signOutFlipsState() async throws {
        let session = AuthSession(userId: UUID(), email: "andrei@example.com")
        let client = MockAuthClient(initialSession: session)
        let service = AuthService(client: client)
        await service.waitForBootstrapTimeout()
        #expect(service.isSignedIn == true)

        try await service.signOut()
        await service.waitForEvent(timeout: .milliseconds(500))
        #expect(service.state == .signedOut)
    }

    // MARK: - Event-driven transitions

    @Test("External token refresh keeps state .signedIn, updates session")
    @MainActor
    func tokenRefreshUpdatesSession() async {
        let original = AuthSession(userId: UUID(), email: "old@example.com")
        let client = MockAuthClient(initialSession: original)
        let service = AuthService(client: client)
        await service.waitForBootstrapTimeout()

        let refreshed = AuthSession(userId: original.userId, email: "new@example.com")
        await client.emitTokenRefresh(session: refreshed)
        await service.waitForEvent(timeout: .milliseconds(500))

        #expect(service.userEmail == "new@example.com")
        #expect(service.userId == original.userId)
    }

    @Test("Server-side sign-out flips state to .signedOut")
    @MainActor
    func externalSignOut() async {
        let session = AuthSession(userId: UUID(), email: "a@b.c")
        let client = MockAuthClient(initialSession: session)
        let service = AuthService(client: client)
        await service.waitForBootstrapTimeout()
        #expect(service.isSignedIn == true)

        await client.emitExternalSignOut()
        await service.waitForEvent(timeout: .milliseconds(500))
        #expect(service.state == .signedOut)
    }

    // MARK: - Convenience properties

    @Test("userInitial falls back to '?' when there's no email")
    @MainActor
    func initialFallback() async {
        let client = MockAuthClient(initialSession: AuthSession(userId: UUID(), email: nil))
        let service = AuthService(client: client)
        await service.waitForBootstrapTimeout()
        #expect(service.userInitial == "?")
    }
}

// MARK: - Helpers

private enum SampleError: Error { case boom }

/// Records every (UUID) callback for assertions.
private actor CallRecorder {
    var calls: [UUID] = []
    func record(_ uuid: UUID) {
        calls.append(uuid)
    }
}

@MainActor
private extension AuthService {
    /// Waits for the mock's initial event after bootstrap; timeout guards against it never arriving.
    func waitForBootstrapTimeout(_ timeout: Duration = .milliseconds(500)) async {
        await waitForEvent(timeout: timeout)
    }

    /// The observation loop runs forever, so we sleep briefly to flush pending event-stream work.
    func waitForEvent(timeout: Duration = .milliseconds(100)) async {
        try? await Task.sleep(for: timeout)
    }
}
