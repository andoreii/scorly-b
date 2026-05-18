import ScorlyData
import ScorlyDesignSystem
import ScorlyFeatureAuth
import SwiftUI

/// Root scene. Auth gate over a bare-bones signed-in placeholder until
/// the round-flow features land.
struct RootView: View {
    let authService: AuthService

    var body: some View {
        AuthGateView(authService: authService) {
            SignedInPlaceholder(authService: authService)
        }
    }
}
