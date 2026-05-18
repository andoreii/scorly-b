import Testing
@testable import ScorlyData

struct ScorlyDataSmokeTests {
    @Test("Package skeleton + SupabaseConfig is reachable")
    func skeleton() {
        _ = ScorlyData.self
        #expect(SupabaseConfig.publishableKey.hasPrefix("sb_publishable_"))
        #expect(SupabaseConfig.url.absoluteString.contains("supabase.co"))
    }
}
