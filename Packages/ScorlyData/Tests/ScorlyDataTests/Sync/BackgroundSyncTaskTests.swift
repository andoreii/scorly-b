import Testing
@testable import ScorlyData

/// `BackgroundSyncTask` itself is a thin wrapper around
/// `BGTaskScheduler` (iOS-only). The scheduler can't be exercised from
/// `swift test` — calling `register(forTaskWithIdentifier:)` outside an
/// app launch context throws. So these tests pin the **contract**:
///
/// - the identifier the data layer hands the app target,
/// - the default refresh cadence,
///
/// because `Info.plist` (`BGTaskSchedulerPermittedIdentifiers`) must
/// match this string exactly. A change here without a matching change
/// in `project.yml` breaks BG scheduling silently in production.
struct BackgroundSyncTaskTests {
    @Test("Task identifier is the locked production string")
    func defaultIdentifierMatchesInfoPlist() {
        #expect(BackgroundSyncTask.defaultIdentifier == "com.andrei.Scorly.sync")
    }

    @Test("Default refresh interval is 15 minutes")
    func defaultRefreshIntervalIs15Minutes() {
        #expect(BackgroundSyncTask.defaultRefreshInterval == 15 * 60)
    }
}
