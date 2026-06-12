import Testing
@testable import ScorlyData

/// `BGTaskScheduler` can't be exercised from `swift test`, so this just pins the
/// identifier/interval constants. Must stay in sync with `project.yml`'s Info.plist entry.
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
