import ScorlyData
import ScorlyDesignSystem
import SwiftUI

/// Routes between loading splash, sign-in form, and the authenticated
/// content, driven by `AuthService.state`. The authenticated closure is
/// composed in the app target so this package never needs to know what
/// "home" looks like.
public struct AuthGateView<Authenticated: View>: View {
    private let authService: AuthService
    private let authenticated: () -> Authenticated

    public init(
        authService: AuthService,
        @ViewBuilder authenticated: @escaping () -> Authenticated
    ) {
        self.authService = authService
        self.authenticated = authenticated
    }

    public var body: some View {
        ZStack {
            BrutalistColor.bg.ignoresSafeArea()
            switch authService.state {
            case .loading:
                AuthLoadingView()
            case .signedOut:
                BrutalistAuthView(authService: authService)
            case .signedIn:
                authenticated()
            }
        }
    }
}
