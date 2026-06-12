import ScorlyData
import ScorlyDesignSystem
import SwiftUI

/// Routes between loading splash, sign-in form, and authenticated content
/// based on `AuthService.state`.
/// `onDevBypass` is a DEBUG-only escape hatch wired by the app target to
/// skip auth when no signup flow exists yet.
public struct AuthGateView<Authenticated: View>: View {
    private let authService: AuthService
    private let forceAuthenticated: Bool
    private let onDevBypass: (() -> Void)?
    private let authenticated: () -> Authenticated

    public init(
        authService: AuthService,
        forceAuthenticated: Bool = false,
        onDevBypass: (() -> Void)? = nil,
        @ViewBuilder authenticated: @escaping () -> Authenticated
    ) {
        self.authService = authService
        self.forceAuthenticated = forceAuthenticated
        self.onDevBypass = onDevBypass
        self.authenticated = authenticated
    }

    public var body: some View {
        ZStack {
            BrutalistColor.bg.ignoresSafeArea()
            if forceAuthenticated {
                authenticated()
            } else {
                switch authService.state {
                case .loading:
                    AuthLoadingView()
                case .signedOut:
                    BrutalistAuthView(authService: authService, onDevBypass: onDevBypass)
                case .signedIn:
                    authenticated()
                }
            }
        }
    }
}
