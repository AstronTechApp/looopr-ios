import SwiftUI

/// Three-page intro shown once, before the sign-in screen, to first-time users.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = Self.initialPage
    private let pageCount = 3

    /// DEBUG: launch with `-onboarding.debugStartPage 2` to open on a specific page.
    private static var initialPage: Int {
        #if DEBUG
        return min(max(UserDefaults.standard.integer(forKey: "onboarding.debugStartPage"), 0), 2)
        #else
        return 0
        #endif
    }

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Skip
                HStack {
                    Spacer()
                    if page < pageCount - 1 {
                        Button(L10n.Onboarding.skip) { finish() }
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(LoooprTheme.Colors.primary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .transition(.opacity)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .animation(.easeInOut(duration: LoooprTheme.Animation.fast), value: page)

                // MARK: Pages
                TabView(selection: $page) {
                    OnboardingPage(
                        eyebrow: L10n.Onboarding.page1Eyebrow,
                        title: L10n.Onboarding.page1Title,
                        text: L10n.Onboarding.page1Body
                    ) { OnboardingDurationIllustration() }
                    .tag(0)

                    OnboardingPage(
                        eyebrow: L10n.Onboarding.page2Eyebrow,
                        title: L10n.Onboarding.page2Title,
                        text: L10n.Onboarding.page2Body
                    ) { OnboardingRouteIllustration() }
                    .tag(1)

                    OnboardingPage(
                        eyebrow: L10n.Onboarding.page3Eyebrow,
                        title: L10n.Onboarding.page3Title,
                        text: L10n.Onboarding.page3Body
                    ) { OnboardingNavigationIllustration() }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(LoooprTheme.Animation.standard, value: page)

                // MARK: Footer
                VStack(alignment: .leading, spacing: LoooprTheme.Spacing.lg) {
                    pageDots

                    if page == pageCount - 1 {
                        Text(L10n.Onboarding.locationNote)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(LoooprTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }

                    Button {
                        if page < pageCount - 1 {
                            withAnimation(LoooprTheme.Animation.standard) { page += 1 }
                        } else {
                            finish()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(page < pageCount - 1 ? L10n.Onboarding.next : L10n.Onboarding.getStarted)
                                .contentTransition(.identity)
                            Image(systemName: "arrow.forward")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .buttonStyle(.loooprPrimary)
                }
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .padding(.bottom, LoooprTheme.Spacing.md)
                .animation(.easeInOut(duration: LoooprTheme.Animation.fast), value: page)
            }
        }
        .preferredColorScheme(.light)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? LoooprTheme.Colors.primary : LoooprTheme.Colors.surfaceContainerHigh)
                    .frame(width: index == page ? 22 : 8, height: 8)
                    .animation(LoooprTheme.Animation.snappy, value: page)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Onboarding.pageIndicator(page + 1, pageCount))
    }

    private func finish() {
        OnboardingState.shared.markCompleted()
        onFinish()
    }
}

// MARK: - Page

private struct OnboardingPage<Illustration: View>: View {
    let eyebrow: String
    let title: String
    let text: String
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            illustration()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)

            Spacer(minLength: LoooprTheme.Spacing.xl)

            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.sm) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(LoooprTheme.Colors.primary)

                Text(title)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(text)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
            .padding(.bottom, LoooprTheme.Spacing.lg)
        }
    }
}

#Preview {
    OnboardingView {}
}
