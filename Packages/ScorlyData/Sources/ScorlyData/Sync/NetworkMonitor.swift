import Foundation
import Network

/// Wraps `NWPathMonitor` as a tiny actor with an `AsyncStream<Bool>` of
/// "is the network available right now?" updates. The SyncEngine subscribes
/// to that stream and drains the outbox whenever the answer flips to true.
///
/// Tests inject a `MockNetworkMonitor` instead — the protocol abstracts the
/// stream so the engine doesn't reach for the real `NWPathMonitor` (which
/// can't be controlled deterministically from a test).
public protocol NetworkMonitor: Sendable {
    /// Current best-effort guess at connectivity. Cheap and synchronous;
    /// callers can short-circuit a drain if it returns false.
    func isOnline() async -> Bool
    /// Async stream of online/offline transitions. The first emission is
    /// the current state; subsequent emissions are deltas.
    func updates() async -> AsyncStream<Bool>
}

public actor LiveNetworkMonitor: NetworkMonitor {
    private let monitor = NWPathMonitor()
    private var current = false
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    private var started = false

    public init() {}

    public func isOnline() -> Bool {
        startIfNeeded()
        return current
    }

    public func updates() -> AsyncStream<Bool> {
        startIfNeeded()
        let initial = current
        return AsyncStream { continuation in
            let id = UUID()
            continuation.yield(initial)
            Task { self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func register(id: UUID, continuation: AsyncStream<Bool>.Continuation) {
        continuations[id] = continuation
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { await self?.updateState(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "scorly.network-monitor"))
    }

    private func updateState(online: Bool) {
        guard online != current else { return }
        current = online
        for continuation in continuations.values {
            continuation.yield(online)
        }
    }
}

/// Test fake — flips `setOnline(_:)` from the test, all subscribers get
/// the new value. Deterministic, no NWPathMonitor.
public actor MockNetworkMonitor: NetworkMonitor {
    private var current: Bool
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    public init(initiallyOnline: Bool = true) {
        current = initiallyOnline
    }

    public func isOnline() -> Bool {
        current
    }

    public func updates() -> AsyncStream<Bool> {
        let initial = current
        return AsyncStream { continuation in
            let id = UUID()
            continuation.yield(initial)
            Task { self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    public func setOnline(_ online: Bool) {
        guard online != current else { return }
        current = online
        for continuation in continuations.values {
            continuation.yield(online)
        }
    }

    private func register(id: UUID, continuation: AsyncStream<Bool>.Continuation) {
        continuations[id] = continuation
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
