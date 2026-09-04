import SwiftUI

/// Apple Health connection screen. Write-only: the single permission asked
/// for is to add walks as workouts, and once granted a toggle controls
/// whether every finished walk is saved automatically.
struct HealthSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var settings = SettingsManager.shared
    @State private var authorization: HealthAuthorization = .notDetermined
    @State private var isRequesting = false
    @State private var showPermissionError = false

    private let healthService: HealthWorkoutSaving? =
        ServiceContainer.shared.resolveOptional(HealthWorkoutSaving.self)

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
                        illustrationCard
                        featuresCard
                        connectionCard
                        privacyNote
                    }
                    .padding(.horizontal, LoooprTheme.Spacing.screenHorizontal)
                    .padding(.bottom, LoooprTheme.Spacing.xxl)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task { refreshAuthorization() }
        // Permission can be changed in the Health app; re-read it when the
        // user comes back to Looopr.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshAuthorization() }
        }
        .alert(L10n.HealthSettings.permissionFailed, isPresented: $showPermissionError) {
            Button(L10n.HealthSettings.ok, role: .cancel) {}
        }
    }

    // MARK: - Connection Card

    @ViewBuilder
    private var connectionCard: some View {
        switch authorization {
        case .unavailable:
            messageCard(icon: "heart.slash", message: L10n.HealthSettings.unavailableMessage)

        case .authorized:
            VStack(alignment: .leading, spacing: LoooprTheme.Spacing.sm) {
                Toggle(isOn: $settings.saveWalksToHealth) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.HealthSettings.saveWalksToggle)
                            .font(LoooprTheme.Typography.body.bold())
                            .foregroundStyle(LoooprTheme.Colors.textPrimary)
                        Text(L10n.HealthSettings.saveWalksSubtitle)
                            .font(LoooprTheme.Typography.caption)
                            .foregroundStyle(LoooprTheme.Colors.textSecondary)
                    }
                }
                .tint(LoooprTheme.Colors.primary)

                Label(L10n.HealthSettings.connectedMessage, systemImage: "checkmark.circle.fill")
                    .font(LoooprTheme.Typography.caption)
                    .foregroundStyle(LoooprTheme.Colors.textTertiary)
            }
            .padding(LoooprTheme.Spacing.md)
            .background(LoooprTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
            .loooprShadow(LoooprTheme.Shadows.sm)

        case .denied:
            VStack(spacing: LoooprTheme.Spacing.md) {
                messageCard(icon: "heart.slash", message: L10n.HealthSettings.deniedMessage)

                Button {
                    if let url = URL(string: "x-apple-health://") { openURL(url) }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                        Text(L10n.HealthSettings.openHealthApp)
                    }
                    .font(LoooprTheme.Typography.body.bold())
                    .foregroundStyle(LoooprTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LoooprTheme.Spacing.md)
                    .background(LoooprTheme.Colors.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.button))
                }
            }

        case .notDetermined:
            Button {
                Task { await connect() }
            } label: {
                HStack {
                    if isRequesting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "heart.fill")
                    }
                    Text(L10n.HealthSettings.connectAppleHealth)
                }
                .font(LoooprTheme.Typography.body.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LoooprTheme.Spacing.md)
                .background(LoooprTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.button))
            }
            .disabled(isRequesting)
        }
    }

    private func messageCard(icon: String, message: String) -> some View {
        HStack(alignment: .top, spacing: LoooprTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: LoooprTheme.Typography.md))
                .foregroundStyle(LoooprTheme.Colors.textTertiary)
                .frame(width: 28)
                .padding(.top, 2)
            Text(message)
                .font(LoooprTheme.Typography.body)
                .foregroundStyle(LoooprTheme.Colors.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(LoooprTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(LoooprTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: LoooprTheme.Radius.card))
        .loooprShadow(LoooprTheme.Shadows.sm)
    }

    // MARK: - Actions

    private func refreshAuthorization() {
        authorization = healthService?.authorization ?? .unavailable
    }

    private func connect() async {
        guard let healthService else { return }
        isRequesting = true
        defer { isRequesting = false }
        do {
            let result = try await healthService.requestAuthorization()
            authorization = result
            // Connecting is the intent; turn the auto-save on so the user
            // doesn't have to find a second switch.
            if result == .authorized { settings.saveWalksToHealth = true }
        } catch {
            showPermissionError = true
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
                title: L10n.HealthSettings.featureWorkoutsTitle,
                description: L10n.HealthSettings.featureWorkoutsDescription
            )

            Divider().padding(.leading, 52)

            featureRow(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                title: L10n.HealthSettings.featureDistanceTitle,
                description: L10n.HealthSettings.featureDistanceDescription
            )

            Divider().padding(.leading, 52)

            featureRow(
                icon: "map.fill",
                title: L10n.HealthSettings.featureRouteTitle,
                description: L10n.HealthSettings.featureRouteDescription
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
