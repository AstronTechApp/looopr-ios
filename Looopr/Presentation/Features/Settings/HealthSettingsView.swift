import SwiftUI

struct HealthSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingComingSoon = false

    var body: some View {
        ZStack {
            LoooprTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: LoooprTheme.Typography.lg, weight: .semibold))
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                    }

                    Spacer()

                    Text(L10n.HealthSettings.appleHealth)
                        .font(LoooprTheme.Typography.headline)
                        .foregroundStyle(LoooprTheme.Colors.textPrimary)

                    Spacer()

                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                .padding(.top, LoooprTheme.Spacing.sm)
                .padding(.bottom, LoooprTheme.Spacing.md)

                ScrollView {
                    VStack(spacing: LoooprTheme.Spacing.lg) {
                        // Illustration card
                        illustrationCard

                        // Features list
                        featuresCard

                        // Connect button
                        Button {
                            showingComingSoon = true
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text(L10n.HealthSettings.connectAppleHealth)
                            }
                            .font(LoooprTheme.Typography.body.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LoooprTheme.Spacing.md)
                            .background(LoooprTheme.Colors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.button))
                        }

                        // Privacy note
                        privacyNote
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                    .padding(.bottom, LoooprTheme.Spacing.xxl)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .alert(L10n.HealthSettings.comingSoon, isPresented: $showingComingSoon) {
            Button(L10n.HealthSettings.ok, role: .cancel) {}
        } message: {
            Text(L10n.HealthSettings.comingSoon)
        }
    }

    // MARK: - Illustration Card

    private var illustrationCard: some View {
        VStack(spacing: LoooprTheme.Spacing.md) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(LoooprTheme.Colors.primary.opacity(0.8))
                .padding(.top, LoooprTheme.Spacing.lg)

            Text(L10n.HealthSettings.syncWithAppleHealth)
                .font(LoooprTheme.Typography.title)
                .foregroundStyle(LoooprTheme.Colors.textPrimary)

            Text(L10n.HealthSettings.descriptionMessage)
                .font(LoooprTheme.Typography.body)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, LoooprTheme.Spacing.md)
                .padding(.bottom, LoooprTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.sm)
    }

    // MARK: - Features Card

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            featureRow(
                icon: "figure.walk",
                title: "Walking Workouts",
                description: "Automatically save completed walks as workouts"
            )

            Divider().padding(.leading, 52)

            featureRow(
                icon: "flame.fill",
                title: "Calories & Distance",
                description: "Track calories burned and distance walked"
            )

            Divider().padding(.leading, 52)

            featureRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Step Count",
                description: "Enrich your progress stats with health data"
            )

            Divider().padding(.leading, 52)

            featureRow(
                icon: "map.fill",
                title: "Route Tracking",
                description: "Save GPS routes with your walk history"
            )
        }
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.sm)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: LoooprTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: LoooprTheme.Typography.md))
                .foregroundStyle(LoooprTheme.Colors.primary)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LoooprTheme.Typography.body.bold())
                    .foregroundStyle(LoooprTheme.Colors.textPrimary)
                Text(description)
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, LoooprTheme.Spacing.md)
        .padding(.vertical, LoooprTheme.Spacing.sm)
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: LoooprTheme.Spacing.sm) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(LoooprTheme.Colors.textTertiary)

            Text(L10n.HealthSettings.privacyMessage)
                .font(LoooprTheme.Typography.caption)
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
        }
        .padding(.horizontal, LoooprTheme.Spacing.sm)
    }
}
