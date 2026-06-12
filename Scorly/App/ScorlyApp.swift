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
        // Must happen before the first scene so Font.custom(...) resolves.
        ScorlyDesignSystem.registerFonts()

        do {
            modelContainer = try LocalSchema.makeContainer()
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }

        // Shared client so auth, sync, and direct calls reuse one session.
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
