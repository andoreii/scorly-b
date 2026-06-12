import Foundation
import Network

/// Abstracts connectivity so the SyncEngine can drain the outbox on offline -> online
/// transitions; tests use `MockNetworkMonitor` instead of `NWPathMonitor`.
public protocol NetworkMonitor: Sendable {
    /// Best-effort current connectivity, for short-circuiting a drain.
    func isOnline() async -> Bool
    /// Online/offline transitions; first emission is the current state.
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

/// Test fake: `setOnline(_:)` notifies all subscribers deterministically, no NWPathMonitor.
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
