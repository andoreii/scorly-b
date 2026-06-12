import Foundation

/// BGAppRefreshTask plumbing — iOS-only, no-op on macOS so the package builds in `swift test`.
/// The handler has a hard deadline (~25s) to drain what it can, reschedule, and complete.
public enum BackgroundSyncTask {
    public static let defaultIdentifier = "com.andrei.Scorly.sync"
    public static let defaultRefreshInterval: TimeInterval = 15 * 60 // 15 minutes
}

#if canImport(BackgroundTasks) && os(iOS)
@preconcurrency import BackgroundTasks

public extension BackgroundSyncTask {
    /// Registers the BGAppRefreshTask identifier and handler. Call once at app launch.
    static func register(
        taskIdentifier: String = defaultIdentifier,
        scheduler: BGTaskScheduler = .shared,
        handler: @escaping @Sendable () async -> Void
    ) {
        scheduler.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            // Schedule the next pass first so a crash doesn't strand us.
            scheduleNext(taskIdentifier: taskIdentifier, scheduler: scheduler)
            let work = Task {
                await handler()
            }
            task.expirationHandler = { work.cancel() }
            Task {
                _ = await work.result
                task.setTaskCompleted(success: !work.isCancelled)
            }
        }
    }

    /// Schedule the next refresh; call on background and from inside the handler.
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
