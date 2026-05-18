import ScorlyData
import ScorlyDesignSystem
import ScorlyDomain
import ScorlyFeatureAuth
import SwiftData
import SwiftUI

@main
struct ScorlyApp: App {
    private let modelContainer: ModelContainer
    private let authService: AuthService
    private let roundsRepository: any RoundsRepository

    init() {
        // Bundled brutalist fonts. Must happen before the first scene
        // materialises so `Font.custom("Geist-…")` resolves correctly.
        ScorlyDesignSystem.registerFonts()

        // Disk-backed SwiftData container — every feature (and the
        // sync engine, when wired in a later phase) shares this one
        // container, attached below via `.modelContainer(_:)`.
        do {
            modelContainer = try LocalSchema.makeContainer()
        } catch {
            // Failing to open the local store is unrecoverable: the
            // offline-first model assumes SwiftData is available.
            fatalError("Failed to construct ModelContainer: \(error)")
        }

        // AuthService with a no-op ensureProfile for now. The bridge to
        // `UsersRepository.upsertProfile` lands once the round-flow
        // features need a populated profile row.
        let supabase = SupabaseClientFactory.make()
        authService = AuthService(client: LiveSupabaseAuthClient(supabase: supabase))

        // Empty rounds repository until phase 6 wires the SyncEngine +
        // RoundsRepositoryLive. Home + History both render the
        // no-rounds-yet empty state while this is in place.
        roundsRepository = InMemoryRoundsRepository()
    }

    var body: some Scene {
        WindowGroup {
            RootView(authService: authService, roundsRepository: roundsRepository)
                .modelContainer(modelContainer)
                .preferredColorScheme(.light)
        }
    }
}
