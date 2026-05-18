import ScorlyData
import ScorlyDesignSystem
import SwiftUI

/// Routes between loading splash, sign-in form, and the authenticated
/// content, driven by `AuthService.state`. The authenticated closure is
/// composed in the app target so this package never needs to know what
/// "home" looks like.
///
/// `onDevBypass` is an optional escape hatch the app target wires in
/// DEBUG only — it lets the developer skip past the auth form when no
/// signup flow exists yet. When the closure runs, the app target flips
/// a bypass flag and re-renders the gate with `forceAuthenticated: true`.
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
