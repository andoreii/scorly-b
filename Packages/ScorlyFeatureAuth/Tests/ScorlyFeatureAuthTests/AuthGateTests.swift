import ScorlyData
import SwiftUI
import Testing
@testable import ScorlyFeatureAuth

@MainActor
struct AuthGateTests {
    @Test("AuthGateView accepts an authenticated content slot")
    func gateAcceptsAuthenticatedSlot() {
        let service = AuthService(client: MockAuthClient())
        _ = AuthGateView(authService: service) { Text("home") }
    }

    @Test("BrutalistAuthView builds with a mock AuthService")
    func authViewConstructs() {
        let service = AuthService(client: MockAuthClient())
        _ = BrutalistAuthView(authService: service)
    }

    @Test("AuthLoadingView is constructible without dependencies")
    func loadingViewConstructs() {
        _ = AuthLoadingView()
    }
}
