import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyFeatureAuth
import Supabase
import SwiftData
import SwiftUI

@main
struct ScorlyApp: App {
    private let modelContainer: ModelContainer
    private let authService: AuthService
    private let supabase: SupabaseClient

    init() {
        // Bundled brutalist fonts. Must happen before the first scene
        // materialises so `Font.custom("Geist-…")` resolves correctly.
        ScorlyDesignSystem.registerFonts()

        // Disk-backed SwiftData container shared by all features and the
        // SyncEngine. One container, one store.
        do {
            modelContainer = try LocalSchema.makeContainer()
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }

        // Single shared Supabase client — auth session, sync API, and
        // direct Supabase calls all share the same keychain-backed session.
        supabase = SupabaseClientFactory.make()
        authService = AuthService(client: LiveSupabaseAuthClient(supabase: supabase))
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                supabase: supabase,
                modelContainer: modelContainer
            )
            .modelContainer(modelContainer)
            .preferredColorScheme(.light)
        }
    }
}
