import ScorlyData
import ScorlyDesignSystem
import SwiftUI

/// Bare-bones sign-in form. Email + password, ink underlines, single
/// CTA. No sign-up, no forgot-password — those slots ship later.
public struct BrutalistAuthView: View {
    let authService: AuthService
    let onDevBypass: (() -> Void)?

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field: Hashable { case email, password }

    public init(authService: AuthService, onDevBypass: (() -> Void)? = nil) {
        self.authService = authService
        self.onDevBypass = onDevBypass
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
            && !isSubmitting
    }

    public var body: some View {
        ScreenShell {
            TopBar(left: "AUTH", right: "SCORLY/B  ®")

            VStack(alignment: .leading, spacing: 0) {
                wordmark
                    .padding(.top, BrutalistSpacing.xl)

                HBar(vMargin: BrutalistSpacing.xl)

                Text("SIGN IN — REQUIRED")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)

                VStack(spacing: BrutalistSpacing.md) {
                    inputField(label: "Email", value: $email, secure: false)
                        .focused($focused, equals: .email)
                    inputField(label: "Password", value: $password, secure: true)
                        .focused($focused, equals: .password)
                }
                .padding(.top, BrutalistSpacing.l)

                if let errorMessage {
                    errorBanner(errorMessage)
                        .padding(.top, BrutalistSpacing.m)
                        .transition(.opacity)
                }

                HBar(vMargin: BrutalistSpacing.xl)

                BrutalistButton(
                    kind: .fg,
                    action: submit,
                    isDisabled: !canSubmit,
                    padding: EdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18)
                ) {
                    Text(isSubmitting ? "Signing in…" : "Sign in")
                        .font(BrutalistType.body)
                        .kerning(-0.2)
                } caption: {
                    Text("→ ENTER")
                        .font(BrutalistType.monoCaption)
                        .kerning(1.2)
                }

                Text("EMAIL + PASSWORD ONLY · NO SIGNUP YET")
                    .font(BrutalistType.monoMicro)
                    .kerning(0.8)
                    .foregroundStyle(BrutalistColor.dim)
                    .padding(.top, BrutalistSpacing.l)

                if let onDevBypass {
                    devBypassRow(action: onDevBypass)
                        .padding(.top, BrutalistSpacing.l)
                }
            }
        }
    }

    private func devBypassRow(action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(BrutalistColor.hair)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
                Text("DEV")
                    .font(BrutalistType.monoMicro)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.dim)
                Rectangle()
                    .fill(BrutalistColor.hair)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity)
            }
            HStack {
                Text("↳ BYPASS · ENTER WITHOUT AUTH")
                    .font(BrutalistType.monoCaption)
                    .kerning(1.0)
                Spacer()
                Text("→ SKIP")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.0)
                    .foregroundStyle(BrutalistColor.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundStyle(BrutalistColor.fg)
            .overlay(Rectangle().stroke(BrutalistColor.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            .brutalistTap {
                Haptics.light()
                action()
            }
        }
    }

    private var wordmark: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MODEL /B — SCORECARD OS")
                    .font(BrutalistType.monoLabel)
                    .kerning(1.4)
                    .foregroundStyle(BrutalistColor.muted)
                Text(
                    "\(Text("SCOR\nLY").font(BrutalistType.wordmark).kerning(-3).foregroundColor(BrutalistColor.fg))\(Text("/B").font(BrutalistType.sans(.regular, size: 76)).foregroundColor(BrutalistColor.fg))"
                )
                .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("NO.").font(BrutalistType.monoMicro).foregroundStyle(BrutalistColor.muted)
                Text("001").font(BrutalistType.mono(.semibold, size: 22)).monospacedDigit()
            }
            .padding(.bottom, 6)
        }
    }

    private func inputField(label: String, value: Binding<String>, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(BrutalistType.monoMicro)
                .kerning(0.8)
                .foregroundStyle(BrutalistColor.muted)
            if secure {
                SecureField(String(""), text: value)
                    .font(BrutalistType.inputBody)
                    .foregroundStyle(BrutalistColor.fg)
                    .textFieldStyle(.plain)
            } else {
                emailField(value: value)
            }
            Rectangle()
                .fill(BrutalistColor.fg)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func emailField(value: Binding<String>) -> some View {
        #if os(iOS)
        TextField(String(""), text: value)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .font(BrutalistType.inputBody)
            .foregroundStyle(BrutalistColor.fg)
            .textFieldStyle(.plain)
        #else
        TextField(String(""), text: value)
            .autocorrectionDisabled()
            .font(BrutalistType.inputBody)
            .foregroundStyle(BrutalistColor.fg)
            .textFieldStyle(.plain)
        #endif
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("✕")
                .font(BrutalistType.monoCaption)
                .foregroundStyle(BrutalistColor.invFg)
            Text(text.uppercased())
                .font(BrutalistType.monoLabel)
                .kerning(0.6)
                .foregroundStyle(BrutalistColor.invFg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(BrutalistColor.invBg)
    }

    private func submit() {
        guard canSubmit else { return }
        focused = nil
        withAnimation(Motion.adaptive(Motion.snap, reduceMotion: reduceMotion)) {
            errorMessage = nil
            isSubmitting = true
        }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            do {
                try await authService.signIn(email: trimmed, password: password)
            } catch {
                Haptics.error()
                withAnimation(Motion.adaptive(Motion.easeOutQuart, reduceMotion: reduceMotion)) {
                    errorMessage = authService.lastError?.message ?? error.localizedDescription
                }
            }
            isSubmitting = false
        }
    }
}
