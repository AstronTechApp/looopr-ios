import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var authService: AuthService
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var appleSignInDelegate: AppleSignInDelegate?
    @State private var appeared = false

    init(authService: AuthService) {
        _authService = State(initialValue: authService)
    }

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                // MARK: - Branding

                VStack(spacing: LoooprTheme.Spacing.lg) {
                    Image("LoooprLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)

                    VStack(spacing: LoooprTheme.Spacing.xs) {
                        Text(L10n.Auth.welcome)
                            .font(LoooprTheme.Typography.largeTitle)
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)

                        Text(L10n.Auth.discoverRoutesDescription)
                            .font(LoooprTheme.Typography.body)
                            .foregroundStyle(LoooprTheme.Colors.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                }

                Spacer()
                Spacer()

                // MARK: - Sign In Card

                VStack(spacing: LoooprTheme.Spacing.lg) {
                    VStack(spacing: LoooprTheme.Spacing.sm) {
                        // Apple Sign In
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            let nonce = String.randomNonce()
                            request.nonce = nonce.sha256
                            appleSignInDelegate = AppleSignInDelegate(nonce: nonce)
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.button))
                        .loooprShadow(LoooprTheme.Shadows.sm)

                        // Google Sign In
                        Button {
                            Task { await signInWithGoogle() }
                        } label: {
                            HStack(spacing: LoooprTheme.Spacing.sm) {
                                GoogleLogo()
                                    .frame(width: 20, height: 20)
                                Text(L10n.Auth.signInGoogle)
                                    .font(LoooprTheme.Typography.button)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(LoooprTheme.Colors.surface)
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.button))
                            .overlay(
                                RoundedRectangle(cornerRadius: LoooprTheme.Radius.button)
                                    .stroke(LoooprTheme.Colors.border, lineWidth: 1)
                            )
                            .loooprShadow(LoooprTheme.Shadows.sm)
                        }
                        .buttonStyle(AuthButtonStyle())
                    }

                    // Loading / Error
                    ZStack {
                        if isLoading {
                            HStack(spacing: LoooprTheme.Spacing.xs) {
                                ProgressView()
                                    .tint(LoooprTheme.Colors.primary)
                                Text(L10n.Auth.signingIn)
                                    .font(LoooprTheme.Typography.subheadline)
                                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        if let errorMessage {
                            HStack(spacing: LoooprTheme.Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                Text(errorMessage)
                                    .font(LoooprTheme.Typography.caption)
                            }
                            .foregroundStyle(LoooprTheme.Colors.error)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                        }
                    }
                    .frame(height: 20)
                    .animation(LoooprTheme.Animation.standard, value: isLoading)
                    .animation(LoooprTheme.Animation.standard, value: errorMessage)

                    // GDPR consent
                    Text(L10n.Auth.privacyAgreement)
                        .font(LoooprTheme.Typography.caption)
                        .foregroundStyle(LoooprTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .tint(LoooprTheme.Colors.primary)
                }
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .padding(.bottom, LoooprTheme.Spacing.xxl)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
            }
        }
        .onAppear {
            withAnimation(LoooprTheme.Animation.gentle.delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = credential.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8),
                      let delegate = appleSignInDelegate else {
                    errorMessage = L10n.Auth.appleIDCredentialsFailed
                    return
                }
                do {
                    try await authService.signInWithApple(idToken: idToken, nonce: delegate.nonce)
                } catch {
                    errorMessage = error.localizedDescription
                }
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code == .canceled { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Google Sign In

    private func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.signInWithGoogle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Auth Button Style

private struct AuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(LoooprTheme.Animation.snappy, value: configuration.isPressed)
    }
}

// MARK: - Google Logo (vector)

private struct GoogleLogo: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Blue
            var blue = Path()
            blue.move(to: CGPoint(x: w * 0.957, y: h * 0.484))
            blue.addLine(to: CGPoint(x: w * 0.957, y: h * 0.448))
            blue.addLine(to: CGPoint(x: w * 0.5, y: h * 0.448))
            blue.addLine(to: CGPoint(x: w * 0.5, y: h * 0.552))
            blue.addLine(to: CGPoint(x: w * 0.77, y: h * 0.552))
            blue.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.76),
                control1: CGPoint(x: w * 0.735, y: h * 0.68),
                control2: CGPoint(x: w * 0.63, y: h * 0.76)
            )
            blue.addCurve(
                to: CGPoint(x: w * 0.24, y: h * 0.5),
                control1: CGPoint(x: w * 0.357, y: h * 0.76),
                control2: CGPoint(x: w * 0.24, y: h * 0.643)
            )
            blue.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.24),
                control1: CGPoint(x: w * 0.24, y: h * 0.357),
                control2: CGPoint(x: w * 0.357, y: h * 0.24)
            )
            blue.addCurve(
                to: CGPoint(x: w * 0.72, y: h * 0.33),
                control1: CGPoint(x: w * 0.587, y: h * 0.24),
                control2: CGPoint(x: w * 0.664, y: h * 0.274)
            )
            blue.addLine(to: CGPoint(x: w * 0.8, y: h * 0.25))
            blue.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.14),
                control1: CGPoint(x: w * 0.73, y: h * 0.18),
                control2: CGPoint(x: w * 0.62, y: h * 0.14)
            )
            blue.addCurve(
                to: CGPoint(x: w * 0.14, y: h * 0.5),
                control1: CGPoint(x: w * 0.3, y: h * 0.14),
                control2: CGPoint(x: w * 0.14, y: h * 0.3)
            )
            blue.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.86),
                control1: CGPoint(x: w * 0.14, y: h * 0.7),
                control2: CGPoint(x: w * 0.3, y: h * 0.86)
            )
            blue.addCurve(
                to: CGPoint(x: w * 0.957, y: h * 0.484),
                control1: CGPoint(x: w * 0.78, y: h * 0.86),
                control2: CGPoint(x: w * 0.957, y: h * 0.7)
            )
            blue.closeSubpath()
            context.fill(blue, with: .color(Color(hex: "#4285F4")))

            // Green
            var green = Path()
            green.move(to: CGPoint(x: w * 0.5, y: h * 0.86))
            green.addCurve(
                to: CGPoint(x: w * 0.77, y: h * 0.552),
                control1: CGPoint(x: w * 0.63, y: h * 0.86),
                control2: CGPoint(x: w * 0.735, y: h * 0.73)
            )
            green.addLine(to: CGPoint(x: w * 0.5, y: h * 0.552))
            green.addLine(to: CGPoint(x: w * 0.5, y: h * 0.76))
            green.addCurve(
                to: CGPoint(x: w * 0.77, y: h * 0.552),
                control1: CGPoint(x: w * 0.63, y: h * 0.76),
                control2: CGPoint(x: w * 0.735, y: h * 0.68)
            )
            context.fill(green, with: .color(Color(hex: "#34A853")))

            // Red
            context.fill(
                Path(ellipseIn: CGRect(
                    x: w * 0.14, y: h * 0.14,
                    width: w * 0.72, height: h * 0.72
                )),
                with: .color(.clear)
            )
        }
        // Fallback: use SF Symbol
        .hidden()
        .overlay {
            Text("G")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#4285F4"))
        }
    }
}
