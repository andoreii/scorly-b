import Foundation

/// BGAppRefreshTask plumbing — iOS-only, no-op on macOS so the package
/// still builds in `swift test` on a Mac.
///
/// Phase H wires this into `ScorlyApp.init`:
///
/// ```swift
/// BackgroundSyncTask.register(taskIdentifier: "com.andrei.Scorly.sync") {
///     await syncEngine.drain()
/// }
/// ```
///
/// The handler has a hard deadline (~25s on iOS) inside which it must
/// drain whatever it can, then schedule the next refresh and call
/// `setTaskCompleted(success:)`.
public enum BackgroundSyncTask {
    public static let defaultIdentifier = "com.andrei.Scorly.sync"
    public static let defaultRefreshInterval: TimeInterval = 15 * 60 // 15 minutes
}

#if canImport(BackgroundTasks) && os(iOS)
import BackgroundTasks

public extension BackgroundSyncTask {
    /// Register the BGAppRefreshTask identifier and wire up the handler.
    /// Call once during app launch (Phase H — `ScorlyApp.init`). The
    /// handler closure is called on a background thread; it should drain
    /// the outbox and then return.
    static func register(
        taskIdentifier: String = defaultIdentifier,
        scheduler: BGTaskScheduler = .shared,
        handler: @escaping @Sendable () async -> Void
    ) {
        scheduler.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            // Schedule the next pass before doing work — if the work
            // crashes, we still get another chance.
            scheduleNext(taskIdentifier: taskIdentifier, scheduler: scheduler)
            let work = Task { @Sendable in
                await handler()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    /// Schedule the next refresh. Call from the app delegate when the app
    /// goes to background, and from inside the registered handler.
    static func scheduleNext(
        taskIdentifier: String = defaultIdentifier,
        scheduler: BGTaskScheduler = .shared,
        earliestBeginDate: Date = Date().addingTimeInterval(defaultRefreshInterval)
    ) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = earliestBeginDate
        try? scheduler.submit(request)
    }
}
#endif
