import ScorlyData
import ScorlyDesignSystem
import SwiftUI

/// Temporary screen for the signed-in state. Replaced by the real
/// `HomeView` from `ScorlyFeatureRound` in the next phase. For now it
/// just confirms auth round-trips end to end (sign in → see this →
/// tap SIGN OUT → back to the auth form).
struct SignedInPlaceholder: View {
    let authService: AuthService

    @State private var isSigningOut = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScreenShell {
            TopBar(left: "HOME", right: "SCORLY/B  ®")

            VStack(alignment: .leading, spacing: 6) {
                Text("MODEL /B — SCORECARD OS")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.4)
                    .foregroundStyle(BrutalistColor.muted)
                (
                    Text("SCOR\nLY").font(BrutalistType.wordmark).kerning(-3)
                        + Text("/B").font(BrutalistType.sans(.regular, size: 76))
                )
                .lineLimit(2)
            }
            .padding(.top, BrutalistSpacing.xl)

            HBar(vMargin: BrutalistSpacing.xl)

            VStack(alignment: .leading, spacing: 4) {
                Text("SIGNED IN")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
                Text(authService.userEmail ?? "—")
                    .font(BrutalistType.confirmCardTitle)
                    .foregroundStyle(BrutalistColor.fg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .overlay(Rectangle().stroke(BrutalistColor.rule, lineWidth: 1))

            Text("HOME SCREEN LANDS IN THE NEXT BUILD.")
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.dim)
                .padding(.top, BrutalistSpacing.m)

            HBar(vMargin: BrutalistSpacing.xl)

            BrutalistButton(
                kind: .inv,
                action: signOut,
                isDisabled: isSigningOut,
                padding: EdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18)
            ) {
                Text(isSigningOut ? "Signing out…" : "Sign out")
                    .font(BrutalistType.body)
            } caption: {
                Text("→ EXIT")
                    .font(BrutalistType.monoCaption)
                    .kerning(1.2)
            }
        }
    }

    private func signOut() {
        withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
            isSigningOut = true
        }
        Task { @MainActor in
            try? await authService.signOut()
            isSigningOut = false
        }
    }
}
